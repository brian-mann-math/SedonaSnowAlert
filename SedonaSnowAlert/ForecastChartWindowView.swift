import SwiftUI

struct ForecastChartWindowView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var selectedLocationId: UUID?
    @State private var showAllLocations = true
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            HStack {
                Text("Snow Forecast")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if locationManager.locations.count > 1 {
                    Picker("View", selection: $showAllLocations) {
                        Text("All Locations").tag(true)
                        Text("Single Location").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    if showAllLocations || locationManager.locations.count == 1 {
                        // Show all locations
                        ForEach(locationManager.locations) { location in
                            SnowForecastChartView(location: location)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    } else {
                        // Single location picker and chart
                        VStack(spacing: 16) {
                            Picker("Location", selection: $selectedLocationId) {
                                ForEach(locationManager.locations) { location in
                                    Text(location.name).tag(Optional(location.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 300)

                            if let locationId = selectedLocationId,
                               let location = locationManager.locations.first(where: { $0.id == locationId }) {
                                SnowForecastChartView(location: location)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }

                    // Last updated info
                    if let lastChecked = locationManager.locations.first?.lastChecked {
                        Text("Last updated: \(lastChecked, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Close") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            // Select first location by default
            if selectedLocationId == nil, let first = locationManager.locations.first {
                selectedLocationId = first.id
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}
