import SwiftUI

struct BlockWidgetView: View {
    let block: BreakroomBlock

    var body: some View {
        if let type = block.type {
            switch type {
            case .chat:
                ChatWidget(block: block)
            case .updates:
                UpdatesWidget(block: block)
            case .calendar:
                CalendarWidget(block: block)
            case .weather:
                WeatherWidget(block: block)
            case .news:
                NewsWidget(block: block)
            case .blog:
                BlogWidget(block: block)
            }
        }
    }
}

// MARK: - Widget Placeholders

struct UpdatesWidget: View {
    let block: BreakroomBlock

    @State private var updates: [BreakroomUpdate] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                updatesLoadingView
            } else if let error {
                updatesErrorView(error)
            } else if updates.isEmpty {
                updatesEmptyView
            } else {
                updatesList
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .task {
            await fetchUpdates()
        }
    }

    // MARK: - Loading

    private var updatesLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading updates...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }

    // MARK: - Error

    private func updatesErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    error = nil
                    isLoading = true
                    await fetchUpdates()
                }
            } label: {
                Text("Retry")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }

    // MARK: - Empty

    private var updatesEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("No updates yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }

    // MARK: - Updates List

    private var updatesList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(updates) { update in
                    updateRow(update)
                    if update.id != updates.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 280)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func updateRow(_ update: BreakroomUpdate) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Green accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.green)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                // Date + time
                HStack(spacing: 6) {
                    Text(update.relativeDate)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)

                    if !update.formattedTime.isEmpty {
                        Text(update.formattedTime)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Summary
                Text(update.displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Data

    private func fetchUpdates() async {
        isLoading = true
        error = nil
        do {
            updates = try await BreakroomAPIService.getUpdates()
        } catch {
            self.error = "Failed to load updates"
        }
        isLoading = false
    }
}

// MARK: - Calendar Widget

private struct TimezoneOption: Identifiable {
    let id: String
    let label: String
    init(_ id: String, _ label: String) { self.id = id; self.label = label }
}

private let commonTimezones: [TimezoneOption] = [
    TimezoneOption("America/New_York", "Eastern Time (New York)"),
    TimezoneOption("America/Chicago", "Central Time (Chicago)"),
    TimezoneOption("America/Denver", "Mountain Time (Denver)"),
    TimezoneOption("America/Los_Angeles", "Pacific Time (Los Angeles)"),
    TimezoneOption("America/Anchorage", "Alaska Time"),
    TimezoneOption("Pacific/Honolulu", "Hawaii Time"),
    TimezoneOption("America/Phoenix", "Arizona (No DST)"),
    TimezoneOption("America/Toronto", "Toronto"),
    TimezoneOption("America/Vancouver", "Vancouver"),
    TimezoneOption("America/Mexico_City", "Mexico City"),
    TimezoneOption("America/Sao_Paulo", "Sao Paulo"),
    TimezoneOption("Europe/London", "London (GMT/BST)"),
    TimezoneOption("Europe/Paris", "Paris (CET)"),
    TimezoneOption("Europe/Berlin", "Berlin (CET)"),
    TimezoneOption("Europe/Moscow", "Moscow"),
    TimezoneOption("Asia/Dubai", "Dubai"),
    TimezoneOption("Asia/Kolkata", "India (IST)"),
    TimezoneOption("Asia/Singapore", "Singapore"),
    TimezoneOption("Asia/Shanghai", "China (CST)"),
    TimezoneOption("Asia/Tokyo", "Tokyo (JST)"),
    TimezoneOption("Asia/Seoul", "Seoul (KST)"),
    TimezoneOption("Australia/Sydney", "Sydney (AEST)"),
    TimezoneOption("Australia/Perth", "Perth (AWST)"),
    TimezoneOption("Pacific/Auckland", "Auckland (NZST)"),
    TimezoneOption("UTC", "UTC"),
]

private struct CalendarDay: Identifiable {
    let id: Int // unique index within the grid
    let day: Int
    let currentMonth: Bool
    let isToday: Bool
}

struct CalendarWidget: View {
    let block: BreakroomBlock

    @State private var currentTime = Date()
    @State private var selectedTimezone: String = TimeZone.current.identifier
    @State private var showTimezonePicker = false
    @State private var isSaving = false

    private var effectiveTimeZone: TimeZone {
        TimeZone(identifier: selectedTimezone) ?? .current
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = effectiveTimeZone
        return cal
    }

    // MARK: - Formatted strings

    private var formattedTime: String {
        let f = DateFormatter()
        f.timeZone = effectiveTimeZone
        f.dateFormat = "h:mm:ss a"
        return f.string(from: currentTime)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.timeZone = effectiveTimeZone
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f.string(from: currentTime)
    }

    private var timezoneAbbr: String {
        effectiveTimeZone.abbreviation(for: currentTime) ?? effectiveTimeZone.identifier
    }

    // MARK: - Calendar data

    private var monthYearTitle: String {
        let f = DateFormatter()
        f.timeZone = effectiveTimeZone
        f.dateFormat = "MMMM yyyy"
        return f.string(from: currentTime)
    }

    private var calendarWeeks: [[CalendarDay]] {
        let cal = self.calendar
        let comps = cal.dateComponents([.year, .month, .day], from: currentTime)
        let year = comps.year!
        let month = comps.month!
        let today = comps.day!

        let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let startWeekday = cal.component(.weekday, from: firstOfMonth) // 1=Sun
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count
        let prevMonthDays = cal.range(of: .day, in: .month,
            for: cal.date(byAdding: .month, value: -1, to: firstOfMonth)!)!.count

        var weeks: [[CalendarDay]] = []
        var dayNum = 1
        var nextMonthDay = 1
        var cellIndex = 0

        for _ in 0..<6 {
            var week: [CalendarDay] = []
            for col in 0..<7 {
                if weeks.isEmpty && col < startWeekday - 1 {
                    let d = prevMonthDays - (startWeekday - 2) + col
                    week.append(CalendarDay(id: cellIndex, day: d, currentMonth: false, isToday: false))
                } else if dayNum > daysInMonth {
                    week.append(CalendarDay(id: cellIndex, day: nextMonthDay, currentMonth: false, isToday: false))
                    nextMonthDay += 1
                } else {
                    week.append(CalendarDay(id: cellIndex, day: dayNum, currentMonth: true, isToday: dayNum == today))
                    dayNum += 1
                }
                cellIndex += 1
            }
            weeks.append(week)
            if dayNum > daysInMonth && weeks.count >= 5 { break }
        }
        return weeks
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.4, green: 0.494, blue: 0.918),
                         Color(red: 0.463, green: 0.294, blue: 0.635)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                timeSection
                calendarSection
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await fetchTimezone()
        }
        .task(id: "timer") {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                currentTime = Date()
            }
        }
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(spacing: 2) {
            Text(formattedTime)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(formattedDate)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.9))

            timezoneButton
        }
        .padding(.vertical, 4)
    }

    private var timezoneButton: some View {
        Menu {
            ForEach(commonTimezones) { tz in
                Button {
                    Task { await saveTimezone(tz.id) }
                } label: {
                    if tz.id == selectedTimezone {
                        Label(tz.label, systemImage: "checkmark")
                    } else {
                        Text(tz.label)
                    }
                }
            }
        } label: {
            Text(timezoneAbbr)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.top, 2)
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 4) {
            // Month header
            Text(monthYearTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 3)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(height: 1)
                }

            // Weekday headers
            weekdayHeader

            // Day grid
            ForEach(calendarWeeks, id: \.first?.id) { week in
                weekRow(week)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"], id: \.self) { day in
                Text(day)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekRow(_ days: [CalendarDay]) -> some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                Text("\(day.day)")
                    .font(.system(size: 11, weight: day.isToday ? .bold : .regular))
                    .foregroundStyle(day.isToday
                        ? Color(red: 0.463, green: 0.294, blue: 0.635)
                        : .white.opacity(day.currentMonth ? 1 : 0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(
                        Circle()
                            .fill(day.isToday ? .white : .clear)
                    )
            }
        }
    }

    // MARK: - Data

    private func fetchTimezone() async {
        do {
            let response: ProfileResponse = try await APIClient.shared.request("/api/profile")
            if let tz = response.user.timezone, !tz.isEmpty,
               TimeZone(identifier: tz) != nil {
                selectedTimezone = tz
            }
        } catch {
            // Use device timezone as fallback
        }
    }

    private func saveTimezone(_ tz: String) async {
        isSaving = true
        do {
            let body = ["timezone": tz]
            let _: [String: String] = try await APIClient.shared.request(
                "/api/profile/timezone",
                method: "PUT",
                body: body
            )
            selectedTimezone = tz
        } catch {
            // Silently fail, keep previous timezone
        }
        isSaving = false
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

struct NewsWidget: View {
    let block: BreakroomBlock

    @State private var items: [NewsItem] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                newsLoadingView
            } else if let error {
                newsErrorView(error)
            } else if items.isEmpty {
                newsEmptyView
            } else {
                newsList
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .task {
            await fetchNews()
        }
    }

    // MARK: - Loading

    private var newsLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading news...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }

    // MARK: - Error

    private func newsErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    error = nil
                    isLoading = true
                    await fetchNews()
                }
            } label: {
                Text("Retry")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }

    // MARK: - Empty

    private var newsEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "newspaper")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("No news available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }

    // MARK: - News List

    private var newsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(items.prefix(10))) { item in
                    Button {
                        if let url = URL(string: item.link) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        newsRow(item)
                    }
                    .buttonStyle(.plain)
                    if item.id != items.prefix(10).last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 280)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func newsRow(_ item: NewsItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Red accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.red)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                // Source + time
                HStack(spacing: 4) {
                    if let source = item.source, !source.isEmpty {
                        Text(source.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.red)
                    }

                    if !item.relativeTime.isEmpty {
                        if item.source != nil {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.relativeTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Title
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Description
                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Data

    private func fetchNews() async {
        isLoading = true
        error = nil
        do {
            items = try await BreakroomAPIService.getNews()
        } catch {
            self.error = "Failed to load news"
        }
        isLoading = false
    }
}

// MARK: - Blog Widget

struct BlogWidget: View {
    let block: BreakroomBlock

    @State private var posts: [BlogPost] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                blogLoadingView
            } else if let error {
                blogErrorView(error)
            } else if posts.isEmpty {
                blogEmptyView
            } else {
                blogPostsList
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .navigationDestination(for: BlogPost.self) { post in
            BlogPostView(post: post)
        }
        .task {
            await fetchPosts()
        }
    }

    // MARK: - Loading

    private var blogLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading posts...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }

    // MARK: - Error

    private func blogErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    error = nil
                    isLoading = true
                    await fetchPosts()
                }
            } label: {
                Text("Retry")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }

    // MARK: - Empty

    private var blogEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("No blog posts yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }

    // MARK: - Posts List

    private var blogPostsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(posts.prefix(5))) { post in
                    NavigationLink(value: post) {
                        blogPostRow(post)
                    }
                    .buttonStyle(.plain)
                    if post.id != posts.prefix(5).last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 280)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func blogPostRow(_ post: BlogPost) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Green accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.green)
                .frame(width: 3)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                // Author + date
                HStack(spacing: 4) {
                    Text(post.authorDisplayName)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .lineLimit(1)

                    if !post.relativeDate.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(post.relativeDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Title
                Text(post.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                // Preview
                if !post.plainTextPreview.isEmpty {
                    Text(post.plainTextPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            // Thumbnail
            if let imageURL = post.firstImageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    case .failure:
                        EmptyView()
                    default:
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 52, height: 52)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Data

    private func fetchPosts() async {
        isLoading = true
        error = nil
        do {
            posts = try await BlogAPIService.getFeed()
        } catch {
            self.error = "Failed to load blog posts"
        }
        isLoading = false
    }
}

