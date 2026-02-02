import SwiftUI

struct BlockWidgetView: View {
    let block: BreakroomBlock

    var body: some View {
        switch block.type {
        case .chat:
            ChatWidget(block: block)
        case .updates:
            UpdatesWidgetPlaceholder(block: block)
        case .calendar:
            CalendarWidgetPlaceholder(block: block)
        case .weather:
            WeatherWidget(block: block)
        case .news:
            NewsWidgetPlaceholder(block: block)
        case .blog:
            BlogWidgetPlaceholder(block: block)
        case .placeholder:
            GenericWidgetPlaceholder(block: block)
        }
    }
}

// MARK: - Widget Placeholders

struct UpdatesWidgetPlaceholder: View {
    let block: BreakroomBlock

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Updates feed coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }
}

struct CalendarWidgetPlaceholder: View {
    let block: BreakroomBlock
    @State private var currentTime = Date()

    var body: some View {
        VStack(spacing: 8) {
            Text(currentTime, style: .time)
                .font(.system(size: 32, weight: .light, design: .rounded))

            Text(currentTime, format: .dateTime.weekday(.wide).month(.wide).day().year())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(
            LinearGradient(
                colors: [.purple.opacity(0.15), .indigo.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                currentTime = Date()
            }
        }
    }
}

// MARK: - Weather Widget

private struct WeatherData {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windSpeed: Double
    let windDirection: Int
    let weatherCode: Int
}

private struct ProfileUserPayload: Decodable {
    let city: String?
    let latitude: Double?
    let longitude: Double?
}

private struct ProfileResponse: Decodable {
    let user: ProfileUserPayload
}

private struct LocationUpdatePayload: Decodable {
    let city: String
    let latitude: Double
    let longitude: Double
}

private struct OpenMeteoCurrentUnits: Decodable {
    let temperature_2m: String?
}

private struct OpenMeteoCurrent: Decodable {
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let weather_code: Int
    let wind_speed_10m: Double
    let wind_direction_10m: Int
    let apparent_temperature: Double
}

private struct OpenMeteoResponse: Decodable {
    let current: OpenMeteoCurrent
    let current_units: OpenMeteoCurrentUnits?
}

struct WeatherWidget: View {
    let block: BreakroomBlock

    @State private var weather: WeatherData?
    @State private var isLoading = true
    @State private var error: String?
    @State private var cityName = "Los Angeles"
    @State private var latitude = 34.0522
    @State private var longitude = -118.2437
    @State private var showCityInput = false
    @State private var cityInput = ""
    @State private var isSaving = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0, green: 0.706, blue: 0.859),
                         Color(red: 0, green: 0.514, blue: 0.69)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if isLoading {
                loadingView
            } else if let error {
                errorView(error)
            } else if let weather {
                successView(weather)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await loadProfile()
            await fetchWeather()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Loading weather...")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            Button {
                Task {
                    self.error = nil
                    isLoading = true
                    await fetchWeather()
                }
            } label: {
                Text("Retry")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
    }

    // MARK: - Success

    private func successView(_ data: WeatherData) -> some View {
        VStack(spacing: 12) {
            // City header
            cityHeader

            // Main weather display
            HStack(spacing: 16) {
                Text(weatherEmoji(for: data.weatherCode))
                    .font(.system(size: 48))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(data.temperature))\u{00B0}F")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white)
                    Text("Feels like \(Int(data.feelsLike))\u{00B0}")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            // Description
            Text(weatherDescription(for: data.weatherCode))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))

            // Details panel
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\u{1F4A7} \(data.humidity)%")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text("Humidity")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("\u{1F4A8} \(Int(data.windSpeed)) mph")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text("Wind \(windCompass(data.windDirection))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
    }

    // MARK: - City Header

    private var cityHeader: some View {
        VStack(spacing: 8) {
            if showCityInput {
                HStack(spacing: 8) {
                    TextField("City name", text: $cityInput)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                        .onSubmit {
                            Task { await updateCity() }
                        }

                    Button {
                        Task { await updateCity() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.small)
                        } else {
                            Text("Set")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(isSaving || cityInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                Button {
                    cityInput = cityName
                    showCityInput = true
                } label: {
                    HStack(spacing: 6) {
                        Text(cityName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        do {
            let response: ProfileResponse = try await APIClient.shared.request("/api/profile")
            if let city = response.user.city, !city.isEmpty {
                cityName = city
            }
            if let lat = response.user.latitude, let lon = response.user.longitude {
                latitude = lat
                longitude = lon
            }
        } catch {
            // Use defaults (Los Angeles) if profile fetch fails
        }
    }

    private func fetchWeather() async {
        isLoading = true
        self.error = nil
        do {
            let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,apparent_temperature&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto"
            guard let url = URL(string: urlString) else {
                self.error = "Invalid weather URL"
                isLoading = false
                return
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let c = response.current
            weather = WeatherData(
                temperature: c.temperature_2m,
                feelsLike: c.apparent_temperature,
                humidity: c.relative_humidity_2m,
                windSpeed: c.wind_speed_10m,
                windDirection: c.wind_direction_10m,
                weatherCode: c.weather_code
            )
        } catch {
            self.error = "Failed to load weather"
        }
        isLoading = false
    }

    private func updateCity() async {
        let trimmed = cityInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        do {
            let body = ["city": trimmed]
            let response: LocationUpdatePayload = try await APIClient.shared.request(
                "/api/profile/location",
                method: "PUT",
                body: body
            )
            cityName = response.city
            latitude = response.latitude
            longitude = response.longitude
            showCityInput = false
            await fetchWeather()
        } catch {
            self.error = "Failed to update location"
        }
        isSaving = false
    }

    // MARK: - WMO Weather Codes

    private func weatherEmoji(for code: Int) -> String {
        switch code {
        case 0: return "\u{2600}\u{FE0F}"           // Clear sky
        case 1: return "\u{1F324}\u{FE0F}"          // Mainly clear
        case 2: return "\u{26C5}"                     // Partly cloudy
        case 3: return "\u{2601}\u{FE0F}"            // Overcast
        case 45, 48: return "\u{1F32B}\u{FE0F}"     // Fog
        case 51: return "\u{1F326}\u{FE0F}"          // Light drizzle
        case 53: return "\u{1F326}\u{FE0F}"          // Moderate drizzle
        case 55: return "\u{1F326}\u{FE0F}"          // Dense drizzle
        case 56, 57: return "\u{1F327}\u{FE0F}"     // Freezing drizzle
        case 61: return "\u{1F326}\u{FE0F}"          // Slight rain
        case 63: return "\u{1F327}\u{FE0F}"          // Moderate rain
        case 65: return "\u{1F327}\u{FE0F}"          // Heavy rain
        case 66, 67: return "\u{1F327}\u{FE0F}"     // Freezing rain
        case 71: return "\u{1F328}\u{FE0F}"          // Slight snow
        case 73: return "\u{1F328}\u{FE0F}"          // Moderate snow
        case 75: return "\u{1F328}\u{FE0F}"          // Heavy snow
        case 77: return "\u{2744}\u{FE0F}"           // Snow grains
        case 80: return "\u{1F326}\u{FE0F}"          // Slight rain showers
        case 81: return "\u{1F327}\u{FE0F}"          // Moderate rain showers
        case 82: return "\u{1F327}\u{FE0F}"          // Violent rain showers
        case 85: return "\u{1F328}\u{FE0F}"          // Slight snow showers
        case 86: return "\u{1F328}\u{FE0F}"          // Heavy snow showers
        case 95: return "\u{26C8}\u{FE0F}"           // Thunderstorm
        case 96: return "\u{26C8}\u{FE0F}"           // Thunderstorm with slight hail
        case 99: return "\u{26C8}\u{FE0F}"           // Thunderstorm with heavy hail
        default: return "\u{1F321}\u{FE0F}"          // Unknown
        }
    }

    private func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45: return "Fog"
        case 48: return "Depositing rime fog"
        case 51: return "Light drizzle"
        case 53: return "Moderate drizzle"
        case 55: return "Dense drizzle"
        case 56: return "Light freezing drizzle"
        case 57: return "Dense freezing drizzle"
        case 61: return "Slight rain"
        case 63: return "Moderate rain"
        case 65: return "Heavy rain"
        case 66: return "Light freezing rain"
        case 67: return "Heavy freezing rain"
        case 71: return "Slight snow fall"
        case 73: return "Moderate snow fall"
        case 75: return "Heavy snow fall"
        case 77: return "Snow grains"
        case 80: return "Slight rain showers"
        case 81: return "Moderate rain showers"
        case 82: return "Violent rain showers"
        case 85: return "Slight snow showers"
        case 86: return "Heavy snow showers"
        case 95: return "Thunderstorm"
        case 96: return "Thunderstorm with slight hail"
        case 99: return "Thunderstorm with heavy hail"
        default: return "Unknown"
        }
    }

    // MARK: - Wind Compass

    private func windCompass(_ degrees: Int) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((Double(degrees) + 22.5).truncatingRemainder(dividingBy: 360) / 45)
        return directions[index % 8]
    }
}

struct NewsWidgetPlaceholder: View {
    let block: BreakroomBlock

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "newspaper")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text("News feed coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }
}

struct BlogWidgetPlaceholder: View {
    let block: BreakroomBlock

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text("Blog feed coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }
}

struct GenericWidgetPlaceholder: View {
    let block: BreakroomBlock

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.dashed")
                .font(.largeTitle)
                .foregroundStyle(.gray)

            Text("Empty block")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding()
    }
}
