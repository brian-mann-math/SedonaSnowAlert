import SwiftUI
import CoreLocation

@main
struct SedonaSnowAlertApp: App {
    @StateObject private var weatherService = WeatherService()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var locationManager = LocationManager()
    @State private var addCityWindow: NSWindow?

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                weatherService: weatherService,
                notificationManager: notificationManager,
                locationManager: locationManager,
                showAddCity: { openAddCityWindow() }
            )
        } label: {
            MenuBarLabel(locationManager: locationManager)
        }
        .menuBarExtraStyle(.menu)
    }

    private func openAddCityWindow() {
        if let existingWindow = addCityWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = AddCityView(locationManager: locationManager) {
            addCityWindow?.close()
            addCityWindow = nil
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Add City"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        addCityWindow = window
    }
}

struct MenuBarLabel: View {
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "snowflake")
                .symbolRenderingMode(.palette)
                .foregroundStyle(locationManager.hasAnySnowExpected ? .blue : .gray)
            Text("\(locationManager.maxSnowProbability)%")
                .font(.system(size: 12, weight: .medium))
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var notificationManager: NotificationManager
    @ObservedObject var locationManager: LocationManager
    var showAddCity: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Snow Alert (Days 5-10)")
                .font(.headline)

            Divider()

            // List of locations with 10-day forecast submenu
            ForEach(locationManager.locations) { location in
                Menu("\(location.name) — \(location.snowProbability)%\(location.alertsEnabled ? " \u{1F514}" : "")") {
                    Text("10-Day Snow Forecast")
                        .font(.headline)
                    Divider()

                    if location.dailyForecasts.isEmpty {
                        Text("Loading forecast...")
                    } else {
                        ForEach(location.dailyForecasts) { day in
                            Text("\(day.displayDate): \(day.snowProbability)%\(day.snowfall > 0 ? " (\(String(format: "%.1f", day.snowfall))cm)" : "")")
                        }
                    }

                    Divider()

                    Button(location.alertsEnabled ? "Turn Off Alerts" : "Turn On Alerts") {
                        locationManager.toggleAlerts(for: location)
                    }

                    if locationManager.locations.count > 1 {
                        Button("Remove \(location.name)") {
                            locationManager.removeLocation(location)
                        }
                    }
                }
            }

            Divider()

            if weatherService.isChecking {
                Text("Checking weather...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("Check Now") {
                Task {
                    await weatherService.checkAllLocations(
                        locationManager: locationManager,
                        notificationManager: notificationManager
                    )
                }
            }
            .disabled(weatherService.isChecking)

            Divider()

            Button("Add City...") {
                showAddCity()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
        .onAppear {
            notificationManager.requestPermission()
            weatherService.startPeriodicChecks(
                locationManager: locationManager,
                notificationManager: notificationManager
            )
        }
    }
}

struct LocationRow: View {
    let location: Location
    @ObservedObject var locationManager: LocationManager
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "snowflake")
                .foregroundColor(location.hasSnowExpected ? .blue : .gray)
                .font(.system(size: 12))

            Text(location.name)
                .lineLimit(1)

            Spacer()

            Text("\(location.snowProbability)%")
                .foregroundColor(location.hasSnowExpected ? .blue : .primary)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(minWidth: 35, alignment: .trailing)

            if locationManager.locations.count > 1 {
                Button(action: {
                    locationManager.removeLocation(location)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0.5)
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovering = hovering
        }
        .help(location.forecast ?? "No forecast available")
    }
}

struct AddCityView: View {
    @ObservedObject var locationManager: LocationManager
    var onDismiss: () -> Void
    @State private var searchText = ""
    @State private var searchResults: [GeocodingResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Add City")
                .font(.headline)

            HStack {
                TextField("Search for a city...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        searchCity()
                    }

                Button("Search") {
                    searchCity()
                }
                .disabled(searchText.isEmpty || isSearching)
            }

            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if !searchResults.isEmpty {
                List(searchResults) { result in
                    Button(action: {
                        addCity(result)
                    }) {
                        VStack(alignment: .leading) {
                            Text(result.name)
                                .font(.body)
                            Text(result.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 100, maxHeight: 150)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 380, height: 280)
    }

    private func searchCity() {
        guard !searchText.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        searchResults = []

        Task {
            do {
                let results = try await GeocodingService.search(query: searchText)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                    if results.isEmpty {
                        errorMessage = "No results found"
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Search failed: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }

    private func addCity(_ result: GeocodingResult) {
        let location = Location(
            name: result.name,
            latitude: result.latitude,
            longitude: result.longitude
        )
        locationManager.addLocation(location)
        onDismiss()
    }
}

// Geocoding using Open-Meteo's geocoding API
struct GeocodingResult: Identifiable {
    let id = UUID()
    let name: String
    let displayName: String
    let latitude: Double
    let longitude: Double
}

struct GeocodingService {
    // Nominatim (OpenStreetMap) response structure - more forgiving with typos
    struct NominatimResult: Codable {
        let lat: String
        let lon: String
        let displayName: String
        let name: String?
        let type: String?

        enum CodingKeys: String, CodingKey {
            case lat, lon, name, type
            case displayName = "display_name"
        }
    }

    static func search(query: String) async throws -> [GeocodingResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://nominatim.openstreetmap.org/search?q=\(encodedQuery)&format=json&limit=8&addressdetails=0&featuretype=city"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("SedonaSnowAlert/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let results = try JSONDecoder().decode([NominatimResult].self, from: data)

        return results.compactMap { result in
            guard let lat = Double(result.lat),
                  let lon = Double(result.lon) else {
                return nil
            }

            // Parse display name to get city and region
            let parts = result.displayName.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let cityName = result.name ?? (parts.first ?? "Unknown")
            let regionParts = parts.dropFirst().prefix(2)
            let displayName = regionParts.joined(separator: ", ")

            return GeocodingResult(
                name: cityName,
                displayName: displayName,
                latitude: lat,
                longitude: lon
            )
        }
    }
}
