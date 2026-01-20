import SwiftUI
import Charts

struct SnowForecastChartView: View {
    let location: Location

    private var maxSnowfall: Double {
        location.dailyForecasts.map { $0.snowfall }.max() ?? 1
    }

    private var hasSnowfall: Bool {
        location.dailyForecasts.contains { $0.snowfall > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(location.name)
                .font(.headline)

            if location.dailyForecasts.isEmpty {
                Text("No forecast data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    // Area chart for snow probability
                    ForEach(location.dailyForecasts) { forecast in
                        AreaMark(
                            x: .value("Date", forecast.displayDate),
                            y: .value("Probability", forecast.snowProbability)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Line overlay for precise reading
                    ForEach(location.dailyForecasts) { forecast in
                        LineMark(
                            x: .value("Date", forecast.displayDate),
                            y: .value("Probability", forecast.snowProbability)
                        )
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }

                    // Point markers
                    ForEach(location.dailyForecasts) { forecast in
                        PointMark(
                            x: .value("Date", forecast.displayDate),
                            y: .value("Probability", forecast.snowProbability)
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(forecast.snowProbability > 0 ? 40 : 20)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel(orientation: .verticalReversed)
                            .font(.caption)
                    }
                }
                .frame(height: 200)

                // Snowfall bars if there's any snowfall
                if hasSnowfall {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Predicted Snowfall")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Chart {
                            ForEach(location.dailyForecasts) { forecast in
                                BarMark(
                                    x: .value("Date", forecast.displayDate),
                                    y: .value("Snowfall", forecast.snowfall)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.cyan, Color.blue],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(4)
                            }
                        }
                        .chartYScale(domain: 0...(maxSnowfall > 0 ? maxSnowfall * 1.2 : 1))
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text(String(format: "%.1fcm", doubleValue))
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks { value in
                                AxisValueLabel(orientation: .verticalReversed)
                                    .font(.caption)
                            }
                        }
                        .frame(height: 120)
                    }
                }

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("Snow Probability")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if hasSnowfall {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: 12, height: 8)
                            Text("Snowfall (cm)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
    }
}
