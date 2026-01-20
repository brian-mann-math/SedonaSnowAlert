import Foundation

@MainActor
class WeatherService: ObservableObject {
    @Published var isChecking = false

    private var checkTimer: Timer?
    private let checkInterval: TimeInterval = 6 * 60 * 60 // 6 hours

    private let snowProbabilityThreshold = 20
    private let freezingTempCelsius = 2.0 // ~35°F

    struct WeatherResponse: Codable {
        let daily: DailyData
    }

    struct DailyData: Codable {
        let time: [String]
        let precipitationProbabilityMax: [Int?]
        let temperature2mMin: [Double?]
        let snowfallSum: [Double?]

        enum CodingKeys: String, CodingKey {
            case time
            case precipitationProbabilityMax = "precipitation_probability_max"
            case temperature2mMin = "temperature_2m_min"
            case snowfallSum = "snowfall_sum"
        }
    }

    struct SnowDay {
        let date: String
        let probability: Int
        let minTemp: Double
        let snowfall: Double
    }

    func startPeriodicChecks(locationManager: LocationManager, notificationManager: NotificationManager) {
        // Check on launch
        Task {
            await checkAllLocations(locationManager: locationManager, notificationManager: notificationManager)
        }

        // Schedule periodic checks
        checkTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAllLocations(locationManager: locationManager, notificationManager: notificationManager)
            }
        }
    }

    func checkAllLocations(locationManager: LocationManager, notificationManager: NotificationManager) async {
        guard !isChecking else { return }

        isChecking = true
        defer { isChecking = false }

        for i in 0..<locationManager.locations.count {
            let location = locationManager.locations[i]
            if let updatedLocation = await checkWeatherForLocation(location, notificationManager: notificationManager) {
                locationManager.locations[i] = updatedLocation
            }
        }
    }

    func checkWeatherForLocation(_ location: Location, notificationManager: NotificationManager) async -> Location? {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(location.latitude)&longitude=\(location.longitude)&daily=snowfall_sum,precipitation_probability_max,temperature_2m_min&timezone=auto&forecast_days=16"

        guard let url = URL(string: urlString) else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WeatherResponse.self, from: data)

            let (snowDays, maxProb) = analyzeSnowChance(response: response)
            let dailyForecasts = buildDailyForecasts(response: response)

            var updatedLocation = location
            updatedLocation.snowProbability = maxProb
            updatedLocation.hasSnowExpected = !snowDays.isEmpty
            updatedLocation.lastChecked = Date()
            updatedLocation.forecast = formatForecast(snowDays: snowDays)
            updatedLocation.dailyForecasts = dailyForecasts

            // Send notifications only if alerts are enabled for this location
            if location.alertsEnabled {
                // Check if any day in the 10-day forecast has >20% snow probability
                let daysWithSnow = dailyForecasts.filter { $0.snowProbability > 20 }
                for day in daysWithSnow {
                    let message: String
                    if day.snowfall > 0 {
                        message = "\(String(format: "%.1f", day.snowfall))cm of snow expected"
                    } else {
                        message = "\(day.snowProbability)% chance of snow"
                    }
                    notificationManager.sendSnowAlert(location: location.name, date: day.displayDate, details: message)
                }
            }

            return updatedLocation

        } catch {
            print("Weather check error for \(location.name): \(error)")
            return nil
        }
    }

    private func buildDailyForecasts(response: WeatherResponse) -> [DailyForecast] {
        var forecasts: [DailyForecast] = []
        let daily = response.daily

        // Build forecast for days 0-10 (11 days total)
        let endDay = min(11, daily.time.count)

        for i in 0..<endDay {
            let date = daily.time[i]
            let precipProb = daily.precipitationProbabilityMax[safe: i].flatMap { $0 } ?? 0
            let minTemp = daily.temperature2mMin[safe: i].flatMap { $0 } ?? 10.0
            let snowfall = daily.snowfallSum[safe: i].flatMap { $0 } ?? 0.0

            // Calculate effective snow probability
            let snowProb: Int
            if snowfall > 0 {
                snowProb = 100
            } else if minTemp < freezingTempCelsius {
                snowProb = precipProb
            } else {
                snowProb = 0
            }

            let forecast = DailyForecast(
                date: date,
                displayDate: formatDate(date),
                snowProbability: snowProb,
                minTemp: minTemp,
                snowfall: snowfall
            )
            forecasts.append(forecast)
        }

        return forecasts
    }

    private func analyzeSnowChance(response: WeatherResponse) -> (snowDays: [SnowDay], maxProbability: Int) {
        var snowDays: [SnowDay] = []
        var maxProbability = 0
        let daily = response.daily

        // Check days 5-10 (indices 5-10, up to available data)
        let startDay = 5
        let endDay = min(10, daily.time.count - 1)

        for i in startDay...endDay {
            guard i < daily.time.count else { continue }

            let date = daily.time[i]
            let precipProb = daily.precipitationProbabilityMax[safe: i].flatMap { $0 } ?? 0
            let minTemp = daily.temperature2mMin[safe: i].flatMap { $0 } ?? 10.0
            let snowfall = daily.snowfallSum[safe: i].flatMap { $0 } ?? 0.0

            // Calculate effective snow probability for this day
            let effectiveSnowProb: Int
            if snowfall > 0 {
                effectiveSnowProb = 100 // Direct snowfall predicted
            } else if minTemp < freezingTempCelsius {
                effectiveSnowProb = precipProb // Freezing temps, use precip probability
            } else {
                effectiveSnowProb = 0 // Too warm for snow
            }

            maxProbability = max(maxProbability, effectiveSnowProb)

            // Snow conditions: either direct snowfall predicted OR precipitation with freezing temps
            let hasSnowChance = snowfall > 0 ||
                (precipProb > snowProbabilityThreshold && minTemp < freezingTempCelsius)

            if hasSnowChance {
                snowDays.append(SnowDay(
                    date: date,
                    probability: precipProb,
                    minTemp: minTemp,
                    snowfall: snowfall
                ))
            }
        }

        return (snowDays, maxProbability)
    }

    private func formatForecast(snowDays: [SnowDay]) -> String {
        if snowDays.isEmpty {
            return "No snow expected in days 5-10"
        } else {
            let descriptions = snowDays.map { day -> String in
                let formattedDate = formatDate(day.date)
                if day.snowfall > 0 {
                    return "\(formattedDate): \(String(format: "%.1f", day.snowfall))cm snow"
                } else {
                    return "\(formattedDate): \(day.probability)% precip, \(String(format: "%.0f", day.minTemp))°C"
                }
            }
            return "Snow possible:\n" + descriptions.joined(separator: "\n")
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d"

        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
