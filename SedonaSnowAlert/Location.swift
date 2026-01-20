import Foundation

struct DailyForecast: Identifiable, Codable, Equatable {
    let id: UUID
    let date: String
    let displayDate: String
    let snowProbability: Int
    let minTemp: Double
    let snowfall: Double

    init(date: String, displayDate: String, snowProbability: Int, minTemp: Double, snowfall: Double) {
        self.id = UUID()
        self.date = date
        self.displayDate = displayDate
        self.snowProbability = snowProbability
        self.minTemp = minTemp
        self.snowfall = snowfall
    }

    var summary: String {
        if snowfall > 0 {
            return "\(displayDate): \(String(format: "%.1f", snowfall))cm snow"
        } else if snowProbability > 0 {
            return "\(displayDate): \(snowProbability)% chance, \(Int(minTemp))°C"
        } else {
            return "\(displayDate): \(snowProbability)%"
        }
    }
}

struct Location: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var snowProbability: Int
    var hasSnowExpected: Bool
    var lastChecked: Date?
    var forecast: String?
    var dailyForecasts: [DailyForecast]
    var alertsEnabled: Bool

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.snowProbability = 0
        self.hasSnowExpected = false
        self.lastChecked = nil
        self.forecast = nil
        self.dailyForecasts = []
        self.alertsEnabled = true // Alerts on by default
    }

    static let sedona = Location(
        name: "Sedona, AZ",
        latitude: 34.8697,
        longitude: -111.7610
    )
}

@MainActor
class LocationManager: ObservableObject {
    @Published var locations: [Location] = []

    private let saveKey = "savedLocations"

    init() {
        loadLocations()
        if locations.isEmpty {
            locations = [Location.sedona]
            saveLocations()
        }
    }

    func addLocation(_ location: Location) {
        var newLocation = location
        // Only one location can have alerts - disable if another already has alerts
        if alertedLocation != nil {
            newLocation.alertsEnabled = false
        }
        locations.append(newLocation)
        saveLocations()
    }

    func removeLocation(at index: Int) {
        guard index < locations.count else { return }
        locations.remove(at: index)
        if locations.isEmpty {
            locations = [Location.sedona]
        }
        saveLocations()
    }

    func removeLocation(_ location: Location) {
        locations.removeAll { $0.id == location.id }
        if locations.isEmpty {
            locations = [Location.sedona]
        }
        saveLocations()
    }

    func updateLocation(_ location: Location) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index] = location
            saveLocations()
        }
    }

    func toggleAlerts(for location: Location) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            if locations[index].alertsEnabled {
                // Turning off alerts for this location
                locations[index].alertsEnabled = false
            } else {
                // Turning on alerts - disable all others first
                for i in 0..<locations.count {
                    locations[i].alertsEnabled = false
                }
                locations[index].alertsEnabled = true
            }
            saveLocations()
        }
    }

    var alertedLocation: Location? {
        locations.first { $0.alertsEnabled }
    }

    var selectedSnowProbability: Int {
        alertedLocation?.snowProbability ?? 0
    }

    var hasSelectedSnowExpected: Bool {
        alertedLocation?.hasSnowExpected ?? false
    }

    private func saveLocations() {
        if let encoded = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func loadLocations() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Location].self, from: data) {
            locations = decoded
        }
    }
}
