import SwiftUI

/// GANTT chart for a project
struct ProjectGanttView: View {
    let projectId: Int
    let tickets: [Ticket]
    let dependencies: [TicketDependency]
    let timeline: [TicketTimelineEntry]

    @State private var includeDone = false
    @State private var tableView = false
    @State private var selectedId: Int?

    private let scheduler = GanttScheduler()
    private let now = Date()

    private var schedule: GanttSchedule {
        scheduler.build(
            tickets: tickets,
            dependencies: dependencies,
            timeline: timeline,
            now: now,
            includeDone: includeDone
        )
    }

    var body: some View {
        let schedule = self.schedule

        ScrollView {
            VStack(spacing: 16) {
                summaryCards(schedule.summary)
                controls
                legend

                if schedule.rows.isEmpty {
                    emptyState
                } else if tableView {
                    ganttTable(rows: schedule.rows)
                } else {
                    ganttChart(schedule: schedule)
                    if let selected = selectedId,
                       let row = schedule.rows.first(where: { $0.ticket.id == selected }) {
                        barDetail(row: row)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Summary Cards

    private func summaryCards(_ summary: GanttSummary) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                summaryCard(
                    "Remaining work",
                    GanttScheduler.formatHours(summary.remainingHours),
                    "across \(summary.activeCount) ticket\(summary.activeCount == 1 ? "" : "s")"
                )
                summaryCard(
                    "Projected finish",
                    summary.projectedFinish.map { scheduler.formatEnd($0) } ?? "—",
                    nil
                )
            }

            if summary.unestimatedCount > 0 || summary.overdueCount > 0 {
                HStack(spacing: 8) {
                    if summary.unestimatedCount > 0 {
                        summaryCard(
                            "Unestimated",
                            "\(summary.unestimatedCount)",
                            "at 1 day each"
                        )
                    }
                    if summary.overdueCount > 0 {
                        summaryCard(
                            "Overdue",
                            "\(summary.overdueCount)",
                            nil,
                            valueColor: .red
                        )
                    }
                }
            }
        }
    }

    private func summaryCard(_ label: String, _ value: String, _ subtext: String?, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(valueColor)
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

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 8) {
            Toggle("Show completed", isOn: $includeDone)

            Picker("View", selection: $tableView) {
                Text("Chart").tag(false)
                Text("Table").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                legendItem(color: .blue, label: "Backlog")
                legendItem(color: .green, label: "On Deck")
                legendItem(color: .orange, label: "In Progress")
                if includeDone {
                    legendItem(color: .gray, label: "Done")
                }
            }
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                        .foregroundStyle(.secondary)
                        .frame(width: 12, height: 12)
                    Text("No estimate")
                        .font(.caption)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 12, height: 12)
                    Text("Overdue")
                        .font(.caption)
                }
            }
            Text("8h = 1 working day · weekends skipped")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tickets.isEmpty
                ? "No tickets in this project yet."
                : "Nothing left to schedule — every ticket is done.")
                .foregroundStyle(.secondary)

            if !tickets.isEmpty && !includeDone {
                Button("Show completed") {
                    includeDone = true
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    // MARK: - GANTT Chart

    private func ganttChart(schedule: GanttSchedule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(schedule.rows) { row in
                ganttRow(row: row, schedule: schedule)
            }

            Text("Tap a row to see details.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func ganttRow(row: GanttRow, schedule: GanttSchedule) -> some View {
        let isSelected = selectedId == row.ticket.id
        let stageColor = colorFor(row.stage)

        return VStack(alignment: .leading, spacing: 4) {
            // Title row
            HStack {
                Text("#\(row.ticket.id)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(row.ticket.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text(row.stage.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(stageColor.opacity(0.2))
                    .foregroundStyle(stageColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Timeline bar
            GeometryReader { geo in
                let barInfo = calculateBarPosition(row: row, schedule: schedule, width: geo.size.width)

                ZStack(alignment: .leading) {
                    // Weekend shading (simplified)
                    Rectangle()
                        .fill(Color.gray.opacity(0.05))
                        .frame(height: 20)

                    // Bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(row.unestimated ? stageColor.opacity(0.4) : stageColor)
                        .frame(width: max(barInfo.width, 4), height: 16)
                        .offset(x: barInfo.offset)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(row.overdue ? Color.red : Color.clear, lineWidth: 2)
                                .frame(width: max(barInfo.width, 4), height: 16)
                                .offset(x: barInfo.offset)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(row.unestimated ? Color.secondary.opacity(0.5) : Color.clear, style: StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
                                .frame(width: max(barInfo.width, 4), height: 16)
                                .offset(x: barInfo.offset)
                        )

                    // Today marker
                    if barInfo.todayOffset >= 0 && barInfo.todayOffset <= geo.size.width {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 1.5, height: 20)
                            .offset(x: barInfo.todayOffset)
                    }
                }
            }
            .frame(height: 20)

            // Date labels
            HStack {
                Text(GanttScheduler.formatDate(row.start, format: "MMM d"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !row.startKnown {
                    Text("(est.)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("→")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(scheduler.formatEnd(row.end))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if row.overdue {
                    Text("Overdue")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            selectedId = selectedId == row.ticket.id ? nil : row.ticket.id
        }
    }

    private struct BarPosition {
        let offset: CGFloat
        let width: CGFloat
        let todayOffset: CGFloat
    }

    private func calculateBarPosition(row: GanttRow, schedule: GanttSchedule, width: CGFloat) -> BarPosition {
        let allRows = schedule.rows
        let earliest = allRows.map { $0.start }.min() ?? now
        let latest = allRows.map { $0.end }.max() ?? now

        let totalDuration = max(latest.timeIntervalSince(earliest), 1)
        let startOffset = row.start.timeIntervalSince(earliest)
        let barDuration = row.end.timeIntervalSince(row.start)
        let todayOffset = now.timeIntervalSince(earliest)

        return BarPosition(
            offset: CGFloat(startOffset / totalDuration) * width,
            width: CGFloat(barDuration / totalDuration) * width,
            todayOffset: CGFloat(todayOffset / totalDuration) * width
        )
    }

    // MARK: - Bar Detail

    private func barDetail(row: GanttRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("#\(row.ticket.id) \(row.ticket.title)")
                .font(.subheadline.weight(.semibold))

            detailRow("Status") {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorFor(row.stage))
                        .frame(width: 10, height: 10)
                    Text(row.stage.rawValue + (row.overdue ? " · overdue" : ""))
                }
            }

            detailRow("Assignee", row.ticket.assigneeDisplayName ?? "Unassigned")
            detailRow("Estimate", row.unestimated
                ? "None — 1 day assumed"
                : (row.ticket.formattedEstimate + (row.stage == .inProgress && !row.overdue ? " · \(GanttScheduler.formatHours(row.remainingHours)) left" : "")))
            detailRow(row.stage == .done ? "Worked" : "Scheduled",
                      "\(GanttScheduler.formatDate(row.start, format: "MMM d"))\(row.startKnown ? "" : " (est.)") → \(scheduler.formatEnd(row.end))")

            if !row.dependsOn.isEmpty {
                detailRow("Depends on", row.dependsOn.map { "#\($0)" }.joined(separator: ", "))
            }

            if !row.externalBlockers.isEmpty {
                detailRow("Waiting on", row.externalBlockers.map { "#\($0)" }.joined(separator: ", ") + " (another project)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        detailRow(label) { Text(value) }
    }

    private func detailRow(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
    }

    // MARK: - GANTT Table

    private func ganttTable(rows: [GanttRow]) -> some View {
        VStack(spacing: 8) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(row.ticket.id) \(row.ticket.title)")
                        .font(.subheadline.weight(.semibold))

                    HStack {
                        Label(row.overdue ? "Overdue" : row.stage.rawValue, systemImage: row.overdue ? "exclamationmark.triangle" : "circle.fill")
                            .font(.caption)
                            .foregroundStyle(row.overdue ? .red : colorFor(row.stage))
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Assignee")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(row.ticket.assigneeDisplayName ?? "—")
                                .font(.caption)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Estimate")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(row.unestimated ? "— (1d)" : row.ticket.formattedEstimate)
                                .font(.caption)
                        }
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(GanttScheduler.formatDate(row.start, format: "MMM d"))\(row.startKnown ? "" : " (est.)")")
                                .font(.caption)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Finish")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(scheduler.formatEnd(row.end))
                                .font(.caption)
                        }
                    }

                    if !row.dependsOn.isEmpty || !row.externalBlockers.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Depends on")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            let deps = row.dependsOn.isEmpty ? "—" : row.dependsOn.map { "#\($0)" }.joined(separator: ", ")
                            let ext = row.externalBlockers.isEmpty ? "" : " (other: \(row.externalBlockers.map { "#\($0)" }.joined(separator: ", ")))"
                            Text(deps + ext)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Helpers

    private func colorFor(_ stage: GanttStage) -> Color {
        switch stage {
        case .backlog: return .blue
        case .onDeck: return .green
        case .inProgress: return .orange
        case .done: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        ProjectGanttView(
            projectId: 1,
            tickets: [],
            dependencies: [],
            timeline: []
        )
    }
}
