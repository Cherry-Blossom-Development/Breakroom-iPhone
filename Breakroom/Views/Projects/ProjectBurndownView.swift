import SwiftUI
import Charts

/// Burndown chart for a project sprint
struct ProjectBurndownView: View {
    let projectId: Int

    @State private var isLoading = true
    @State private var error: String?

    // Data from API
    @State private var data: BurndownResponse?

    // Sprint navigation
    @State private var sprintDays = 14
    @State private var anchor = Date()
    @State private var currentIndex = 0
    @State private var sprintIndex = 0
    @State private var sprint: SprintBounds?

    // View options
    @State private var measure: BurndownMeasure = .work
    @State private var viewMode: BurndownViewMode = .chart
    @State private var selectedDay: Int?

    // Computed burndown
    @State private var burndown: BurndownResult?

    private let calculator = BurndownCalculator()
    private let now = Date()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading burndown...")
            } else if let error = error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await load() }
                    }
                }
            } else if let burndown = burndown, let sprint = sprint {
                burndownContent(burndown: burndown, sprint: sprint)
            }
        }
        .task {
            await load()
        }
    }

    private func burndownContent(burndown: BurndownResult, sprint: SprintBounds) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                sprintNav
                controls
                summaryCards(burndown: burndown)

                if data?.tickets.isEmpty ?? true {
                    Text("This project has no tickets yet.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else if viewMode == .chart {
                    burndownChart(burndown: burndown, sprint: sprint)
                    if let day = selectedDay, let dayData = burndown.days[safe: day] {
                        dayDetail(day: dayData)
                    }
                } else {
                    burndownTable(days: burndown.days)
                }

                if !(data?.tickets.isEmpty ?? true) {
                    notes(burndown: burndown)
                }
            }
            .padding()
        }
    }

    // MARK: - Sprint Navigation

    private var sprintNav: some View {
        VStack(spacing: 4) {
            HStack {
                Button {
                    goToSprint(sprintIndex - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                .disabled(sprintIndex <= 0)

                Spacer()

                VStack(spacing: 2) {
                    Text("Sprint \(sprintIndex + 1)")
                        .font(.headline)
                    if let sprint = sprint {
                        Text("\(BurndownCalculator.formatDate(sprint.start, format: "MMM d")) – \(BurndownCalculator.formatDate(calendar.date(byAdding: .day, value: -1, to: sprint.end) ?? sprint.end, format: "MMM d, yyyy"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    goToSprint(sprintIndex + 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
                .disabled(sprintIndex >= currentIndex)
            }

            if sprintIndex != currentIndex {
                Button("Current sprint") {
                    goToSprint(currentIndex)
                }
                .font(.caption)
            }
        }
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("Measure", selection: $measure) {
                ForEach(BurndownMeasure.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: measure) { _, _ in
                recompute()
            }

            Picker("View", selection: $viewMode) {
                ForEach(BurndownViewMode.allCases, id: \.self) { v in
                    Text(v.rawValue).tag(v)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewMode) { _, _ in
                selectedDay = nil
            }
        }
    }

    // MARK: - Summary Cards

    private func summaryCards(burndown: BurndownResult) -> some View {
        let pace: (String, String)? = {
            guard burndown.started else { return nil }
            let diff = BurndownCalculator.round1(burndown.remaining - burndown.idealNow)
            if abs(diff) < 0.1 {
                return ("On track", "matching the ideal line")
            } else if diff > 0 {
                return ("Behind", "\(BurndownCalculator.formatAmount(diff, measure: measure)) above the ideal line")
            } else {
                return ("Ahead", "\(BurndownCalculator.formatAmount(-diff, measure: measure)) below the ideal line")
            }
        }()

        let stats: [(String, String, String?)] = [
            (burndown.finished ? "Left at sprint end" : "Remaining",
             BurndownCalculator.formatAmount(burndown.remaining, measure: measure),
             "of \(BurndownCalculator.formatAmount(burndown.startRemaining, measure: measure)) at start"),
            ("Completed", BurndownCalculator.formatAmount(burndown.completed, measure: measure), nil),
            ("Added", BurndownCalculator.formatAmount(burndown.added, measure: measure), "new or reopened"),
        ] + (pace.map { [("Pace", $0.0, $0.1)] } ?? [])

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                statCard(label: stat.0, value: stat.1, subtext: stat.2)
            }
        }
    }

    private func statCard(label: String, value: String, subtext: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
            if let subtext = subtext {
                Text(subtext)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Burndown Chart

    private func burndownChart(burndown: BurndownResult, sprint: SprintBounds) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Legend
            HStack(spacing: 16) {
                legendKey(color: .blue, label: "Actual remaining")
                legendKey(color: .gray, label: "Ideal")
                if sprint.start <= now && now < sprint.end {
                    legendKey(color: .red, label: "Today")
                }
            }
            .font(.caption)

            // Chart
            Chart {
                // Ideal line
                ForEach(Array(burndown.days.enumerated()), id: \.offset) { index, day in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Ideal", day.ideal)
                    )
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .interpolationMethod(.linear)
                }

                // Actual line (only for days that have started)
                let startedDays = burndown.days.enumerated().filter { $0.element.remaining != nil }
                ForEach(startedDays, id: \.offset) { index, day in
                    if let remaining = day.remaining {
                        LineMark(
                            x: .value("Day", index),
                            y: .value("Remaining", remaining)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.linear)

                        AreaMark(
                            x: .value("Day", index),
                            y: .value("Remaining", remaining)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                        .interpolationMethod(.linear)
                    }
                }

                // Today marker
                if let todayIndex = burndown.days.firstIndex(where: { $0.isToday }) {
                    RuleMark(x: .value("Today", todayIndex))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }

                // Weekend shading
                ForEach(Array(burndown.days.enumerated()), id: \.offset) { index, day in
                    if day.weekend {
                        RectangleMark(
                            xStart: .value("Start", Double(index) - 0.5),
                            xEnd: .value("End", Double(index) + 0.5)
                        )
                        .foregroundStyle(.gray.opacity(0.05))
                    }
                }

                // Selected day marker
                if let selected = selectedDay {
                    RuleMark(x: .value("Selected", selected))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 7)) { value in
                    if let index = value.as(Int.self), let day = burndown.days[safe: index] {
                        AxisValueLabel {
                            Text(BurndownCalculator.formatDate(day.date, format: "d"))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(BurndownCalculator.num(v))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x - geometry[proxy.plotFrame!].origin.x
                                    if let index: Int = proxy.value(atX: x) {
                                        if burndown.days.indices.contains(index) {
                                            selectedDay = index
                                        }
                                    }
                                }
                        )
                        .onTapGesture { location in
                            let x = location.x - geometry[proxy.plotFrame!].origin.x
                            if let index: Int = proxy.value(atX: x) {
                                if burndown.days.indices.contains(index) {
                                    selectedDay = selectedDay == index ? nil : index
                                }
                            }
                        }
                }
            }
            .frame(height: 280)
            .accessibilityLabel("Burndown chart for sprint \(sprintIndex + 1). \(BurndownCalculator.formatAmount(burndown.remaining, measure: measure)) remaining of \(BurndownCalculator.formatAmount(burndown.startRemaining, measure: measure)). Switch to Table for day-by-day numbers.")

            Text("Tap or drag across the chart to see a day.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func legendKey(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 16, height: 3)
                .clipShape(Capsule())
            Text(label)
        }
    }

    // MARK: - Day Detail

    private func dayDetail(day: BurndownDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(BurndownCalculator.formatDate(day.date, format: "EEE, MMM d"))
                    .font(.subheadline.weight(.semibold))
                if day.isToday {
                    Text("· today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            detailRow("Remaining", day.remaining.map { BurndownCalculator.formatAmount($0, measure: measure) } ?? "Not yet")
            detailRow("Ideal", BurndownCalculator.formatAmount(day.ideal, measure: measure))

            if day.remaining != nil {
                detailRow("Completed", BurndownCalculator.formatAmount(day.completed, measure: measure))
                detailRow("Added", BurndownCalculator.formatAmount(day.added, measure: measure))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    // MARK: - Burndown Table

    private func burndownTable(days: [BurndownDay]) -> some View {
        VStack(spacing: 0) {
            tableRow(["Day", "Remaining", "Ideal", "Completed", "Added"], bold: true)
            Divider()

            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                let future = day.remaining == nil
                tableRow([
                    BurndownCalculator.formatDate(day.date, format: "EEE, MMM d") + (day.isToday ? " (today)" : ""),
                    day.remaining.map { BurndownCalculator.formatShort($0, measure: measure) } ?? "—",
                    BurndownCalculator.formatShort(day.ideal, measure: measure),
                    future ? "—" : BurndownCalculator.formatShort(day.completed, measure: measure),
                    future ? "—" : BurndownCalculator.formatShort(day.added, measure: measure)
                ], bold: day.isToday, dim: future)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func tableRow(_ cells: [String], bold: Bool = false, dim: Bool = false) -> some View {
        HStack {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, text in
                Text(text)
                    .font(.caption)
                    .fontWeight(bold ? .semibold : .regular)
                    .foregroundStyle(dim ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Notes

    private func notes(burndown: BurndownResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(sprintDays / 7)-week sprints, starting \(BurndownCalculator.formatDate(anchor, format: "EEEE, MMM d, yyyy")).")
                .font(.caption)
                .foregroundStyle(.secondary)

            if measure == .work {
                let unestimated = burndown.unestimatedCount > 0
                    ? " \(burndown.unestimatedCount) unestimated ticket\(burndown.unestimatedCount == 1 ? "" : "s") counted as 1 day each."
                    : ""
                Text("Work uses each ticket's current estimate, in 8-hour working days.\(unestimated)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if burndown.approximate {
                Text("Status history is only recorded from Sep 28, 2026; earlier days are reconstructed from resolved dates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Data Loading

    private func load() async {
        isLoading = true
        error = nil

        do {
            let response = try await ProjectAPIService.getBurndown(projectId: projectId)
            data = response

            let projectCreatedAt = calculator.parseApiTime(response.project.createdAt) ?? now
            sprintDays = response.project.sprintDurationDays ?? 14
            anchor = calculator.sprintAnchor(projectCreatedAt)
            currentIndex = calculator.sprintIndexAt(anchor: anchor, sprintDays: sprintDays, date: now)
            sprintIndex = currentIndex

            recompute()
        } catch let e as APIError {
            error = e.localizedDescription
        } catch {
            self.error = "Failed to load burndown data"
        }

        isLoading = false
    }

    private func recompute() {
        guard let data = data else { return }

        sprint = calculator.sprintBounds(anchor: anchor, sprintDays: sprintDays, index: sprintIndex)
        selectedDay = nil

        if let sprint = sprint {
            burndown = calculator.build(
                tickets: data.tickets,
                history: data.history,
                start: sprint.start,
                end: sprint.end,
                now: now,
                measure: measure
            )
        }
    }

    private func goToSprint(_ index: Int) {
        guard index >= 0 && index <= currentIndex else { return }
        sprintIndex = index
        recompute()
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        ProjectBurndownView(projectId: 1)
    }
}
