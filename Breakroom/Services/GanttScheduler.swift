import Foundation

/// Status categories for GANTT display
enum GanttStage: String, CaseIterable {
    case backlog = "Backlog"
    case onDeck = "On Deck"
    case inProgress = "In Progress"
    case done = "Done"

    static func from(status: String) -> GanttStage {
        switch status {
        case "resolved", "closed": return .done
        case "in_progress": return .inProgress
        case "on-deck": return .onDeck
        default: return .backlog // backlog and legacy 'open'
        }
    }
}

/// A single row in the GANTT chart
struct GanttRow: Identifiable {
    let ticket: Ticket
    let stage: GanttStage
    let start: Date
    let end: Date
    let hours: Double
    let remainingHours: Double
    let unestimated: Bool
    let overdue: Bool
    let startKnown: Bool
    let externalBlockers: [Int]
    let dependsOn: [Int]

    var id: Int { ticket.id }
}

/// Summary statistics for GANTT schedule
struct GanttSummary {
    let activeCount: Int
    let remainingHours: Double
    let unestimatedCount: Int
    let overdueCount: Int
    let projectedFinish: Date?
}

/// Complete GANTT schedule result
struct GanttSchedule {
    let rows: [GanttRow]
    let summary: GanttSummary
    let anchor: Date
}

// GANTT schedule for one project's tickets. A port of web's
// frontend/src/utilities/ganttSchedule.js (buildGanttSchedule); keep them in step.
//
// Rules (agreed 2026-09-28):
//   - Scheduling runs in working hours: 8h per working day, Mon-Fri, weekends
//     skipped. An unestimated ticket is treated as 1 working day and flagged.
//   - Unfinished work is scheduled forward from today. A ticket can't start
//     until the tickets it depends on finish.
//   - One person works one ticket at a time: tickets with the same assignee
//     run back to back. Unassigned tickets run in parallel.
//   - In-progress tickets start when they actually moved to in_progress
//     and finish once their estimate's worth of working time has passed -- or
//     today, flagged overdue, if it already has.
//   - Done (resolved/closed) tickets, when shown, use their real start/finish
//     from status history, falling back to resolved_at and the estimate.

class GanttScheduler {
    private let calendar: Calendar
    private let hoursPerDay: Double = 8.0
    private let dayMS: TimeInterval = 24 * 60 * 60
    private let defaultUnestimatedHours: Double = 8.0 // 1 day

    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        self.calendar = cal
    }

    // MARK: - Date Parsing

    func parseApiTime(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    // MARK: - Calendar Helpers

    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    private func dayOfWeek(_ date: Date) -> Int {
        // 0 = Sunday, 6 = Saturday (like JS)
        calendar.component(.weekday, from: date) - 1
    }

    func isWeekend(_ date: Date) -> Bool {
        let weekday = dayOfWeek(date)
        return weekday == 0 || weekday == 6
    }

    func dayOfMonth(_ date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    /// First working-day midnight at or after date's day
    func nextWorkingDay(_ date: Date) -> Date {
        var d = startOfDay(date)
        while isWeekend(d) {
            d = addDays(d, 1)
        }
        return d
    }

    /// Working hours after anchor -> calendar instant
    func workingOffsetToDate(_ anchor: Date, _ hours: Double, asEnd: Bool = false) -> Date {
        var days = Int(floor(hours / hoursPerDay))
        var fraction = (hours - Double(days) * hoursPerDay) / hoursPerDay

        if asEnd && fraction == 0.0 && days > 0 {
            days -= 1
            fraction = 1.0
        }

        var d = anchor
        for _ in 0..<days {
            d = addDays(d, 1)
            while isWeekend(d) {
                d = addDays(d, 1)
            }
        }

        return d.addingTimeInterval(fraction * dayMS)
    }

    /// hours of working time ending at end -> the instant it started
    func subtractWorkingHours(_ end: Date, _ hours: Double) -> Date {
        var remaining = hours
        var cursor = end

        while remaining > 1e-9 {
            let dayStart = startOfDay(cursor.addingTimeInterval(-1))
            if !isWeekend(dayStart) {
                let available = cursor.timeIntervalSince(dayStart) / dayMS * hoursPerDay
                if available >= remaining {
                    return cursor.addingTimeInterval(-(remaining / hoursPerDay * dayMS))
                }
                remaining -= available
            }
            cursor = dayStart
        }

        return cursor
    }

    /// Whole calendar days between two dates
    func daysBetween(_ a: Date, _ b: Date) -> Int {
        let aStart = startOfDay(a)
        let bStart = startOfDay(b)
        return Int(round(bStart.timeIntervalSince(aStart) / dayMS))
    }

    /// Working hours between two dates (weekdays only, 8h per full weekday)
    func workingHoursBetween(_ from: Date, _ to: Date) -> Double {
        if to <= from { return 0 }

        var total = 0.0
        var day = startOfDay(from)

        while day < to {
            let next = addDays(day, 1)
            if !isWeekend(day) {
                let overlap = min(next, to).timeIntervalSince(max(day, from))
                let dayLength = next.timeIntervalSince(day)
                if overlap > 0 {
                    total += overlap / dayLength * hoursPerDay
                }
            }
            day = next
        }

        return total
    }

    // MARK: - Estimate Conversion

    func estimateWorkingHours(amount: String?, unit: String?) -> Double? {
        guard let amountStr = amount, let amount = Double(amountStr), amount > 0,
              let unit = unit else { return nil }

        switch unit {
        case "hours": return amount
        case "days": return amount * hoursPerDay
        case "weeks": return amount * 5 * hoursPerDay
        case "months": return amount * (52.0 / 12.0) * 5 * hoursPerDay
        default: return nil
        }
    }

    // MARK: - Schedule Building

    func build(
        tickets: [Ticket],
        dependencies: [TicketDependency],
        timeline: [TicketTimelineEntry],
        now: Date,
        includeDone: Bool
    ) -> GanttSchedule {
        let anchor = nextWorkingDay(now)
        let history = Dictionary(uniqueKeysWithValues: timeline.map { ($0.ticketId, $0) })
        let ticketById = Dictionary(uniqueKeysWithValues: tickets.map { ($0.id, $0) })

        func assigneeOf(_ ticket: Ticket) -> Int? {
            ticket.assignedTo
        }

        func durationOf(_ ticket: Ticket) -> (Double, Bool) {
            if let hours = estimateWorkingHours(amount: ticket.estimateAmount, unit: ticket.estimateUnit) {
                return (hours, false)
            }
            return (defaultUnestimatedHours, true)
        }

        // Group dependencies by ticket
        let predecessors = Dictionary(grouping: dependencies) { $0.ticketId }

        var rows: [GanttRow] = []
        var finishOffset: [Int: Double] = [:] // ticket id -> working-hour offset it finishes at
        var assigneeFree: [Int: Double] = [:] // assignee id -> offset they're next free

        // 1. In-progress tickets: already underway, occupy their assignee first
        for ticket in tickets.filter({ GanttStage.from(status: $0.status ?? "") == .inProgress }) {
            let (hours, unestimated) = durationOf(ticket)
            let startedAt = parseApiTime(history[ticket.id]?.startedAt)
            let elapsed = startedAt.map { workingHoursBetween($0, anchor) } ?? 0.0
            let remaining = max(hours - elapsed, 0)
            let overdue = startedAt != nil && hours - elapsed <= 0

            finishOffset[ticket.id] = remaining
            if let assignee = assigneeOf(ticket) {
                assigneeFree[assignee] = max(assigneeFree[assignee] ?? 0, remaining)
            }

            rows.append(GanttRow(
                ticket: ticket,
                stage: .inProgress,
                start: (startedAt != nil && startedAt! < anchor) ? startedAt! : anchor,
                end: overdue ? anchor : workingOffsetToDate(anchor, remaining, asEnd: true),
                hours: hours,
                remainingHours: remaining,
                unestimated: unestimated,
                overdue: overdue,
                startKnown: startedAt != nil,
                externalBlockers: [],
                dependsOn: []
            ))
        }

        // 2. Not-started tickets: list scheduling in dependency order
        var pending = Set(tickets
            .filter {
                let stage = GanttStage.from(status: $0.status ?? "")
                return stage == .backlog || stage == .onDeck
            }
            .map { $0.id })
        var blockersOutside: [Int: Set<Int>] = [:]

        // Priority ranking for scheduling
        let priorityRank = ["urgent": 0, "high": 1, "medium": 2, "low": 3]
        let stageRank = ["on-deck": 0, "backlog": 1, "open": 1]

        func isDoneStatus(_ status: String?) -> Bool {
            status == "resolved" || status == "closed"
        }

        // Offset a ticket can start at, or nil if a predecessor isn't scheduled yet
        func readyAt(_ id: Int) -> Double? {
            var earliest = 0.0
            for dep in predecessors[id] ?? [] {
                let pred = ticketById[dep.dependsOnTicketId]
                if isDoneStatus(pred?.status ?? dep.dependsOnStatus) { continue }

                if pred == nil {
                    // Unfinished ticket in another project
                    blockersOutside[id, default: []].insert(dep.dependsOnTicketId)
                    continue
                }

                guard let predFinish = finishOffset[pred!.id] else { return nil }
                earliest = max(earliest, predFinish)
            }
            return earliest
        }

        while !pending.isEmpty {
            var candidates: [(Int, Double)] = pending.compactMap { id in
                readyAt(id).map { (id, $0) }
            }

            // If loops exist, don't hang
            if candidates.isEmpty {
                candidates = pending.map { ($0, 0.0) }
            }

            let sorted = candidates.sorted { a, b in
                if a.1 != b.1 { return a.1 < b.1 }
                let ticketA = ticketById[a.0]!
                let ticketB = ticketById[b.0]!
                let stageA = stageRank[ticketA.status ?? ""] ?? 1
                let stageB = stageRank[ticketB.status ?? ""] ?? 1
                if stageA != stageB { return stageA < stageB }
                let prioA = priorityRank[ticketA.priority ?? ""] ?? 2
                let prioB = priorityRank[ticketB.priority ?? ""] ?? 2
                if prioA != prioB { return prioA < prioB }
                return a.0 < b.0
            }

            let (id, ready) = sorted.first!
            let ticket = ticketById[id]!
            let (hours, unestimated) = durationOf(ticket)
            let assignee = assigneeOf(ticket)
            let start = max(ready, assignee.flatMap { assigneeFree[$0] } ?? 0)
            let end = start + hours

            finishOffset[id] = end
            if let assignee = assignee {
                assigneeFree[assignee] = end
            }
            pending.remove(id)

            rows.append(GanttRow(
                ticket: ticket,
                stage: GanttStage.from(status: ticket.status ?? ""),
                start: workingOffsetToDate(anchor, start),
                end: workingOffsetToDate(anchor, end, asEnd: true),
                hours: hours,
                remainingHours: hours,
                unestimated: unestimated,
                overdue: false,
                startKnown: true,
                externalBlockers: [],
                dependsOn: []
            ))
        }

        // Add dependency links and external blockers
        rows = rows.map { row in
            GanttRow(
                ticket: row.ticket,
                stage: row.stage,
                start: row.start,
                end: row.end,
                hours: row.hours,
                remainingHours: row.remainingHours,
                unestimated: row.unestimated,
                overdue: row.overdue,
                startKnown: row.startKnown,
                externalBlockers: Array(blockersOutside[row.ticket.id] ?? []),
                dependsOn: (predecessors[row.ticket.id] ?? []).map { $0.dependsOnTicketId }
            )
        }

        // 3. Done tickets (optional)
        if includeDone {
            for ticket in tickets.filter({ GanttStage.from(status: $0.status ?? "") == .done }) {
                let (hours, unestimated) = durationOf(ticket)
                let h = history[ticket.id]
                let end = parseApiTime(h?.doneAt) ?? parseApiTime(ticket.resolvedAt) ?? parseApiTime(ticket.updatedAt) ?? anchor
                let startedAt = parseApiTime(h?.startedAt)
                let startKnown = startedAt != nil && startedAt! < end

                rows.append(GanttRow(
                    ticket: ticket,
                    stage: .done,
                    start: startKnown ? startedAt! : subtractWorkingHours(end, hours),
                    end: end,
                    hours: hours,
                    remainingHours: 0,
                    unestimated: unestimated,
                    overdue: false,
                    startKnown: startKnown,
                    externalBlockers: [],
                    dependsOn: (predecessors[ticket.id] ?? []).map { $0.dependsOnTicketId }
                ))
            }
        }

        // Sort by start, end, id
        rows.sort { a, b in
            if a.start != b.start { return a.start < b.start }
            if a.end != b.end { return a.end < b.end }
            return a.ticket.id < b.ticket.id
        }

        let active = rows.filter { $0.stage != .done }
        let summary = GanttSummary(
            activeCount: active.count,
            remainingHours: active.reduce(0) { $0 + $1.remainingHours },
            unestimatedCount: active.filter { $0.unestimated }.count,
            overdueCount: active.filter { $0.overdue }.count,
            projectedFinish: active.max(by: { $0.end < $1.end })?.end
        )

        return GanttSchedule(rows: rows, summary: summary, anchor: anchor)
    }
}

// MARK: - Formatting Helpers

extension GanttScheduler {
    static func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    static func formatHours(_ hours: Double) -> String {
        let hoursPerDay = 8.0
        if hours < hoursPerDay {
            let rounded = (hours * 100).rounded() / 100
            let text = rounded.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(rounded)) : String(rounded)
            return "\(text)h"
        }
        let days = (hours / hoursPerDay * 10).rounded() / 10
        let text = days.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(days)) : String(days)
        return "\(text) working day\(days == 1 ? "" : "s")"
    }

    /// Bars that end exactly at midnight finish at the end of the previous day
    func formatEnd(_ time: Date) -> String {
        let startOfTime = calendar.startOfDay(for: time)
        let nextDay = calendar.date(byAdding: .day, value: -1, to: time) ?? time
        let displayDate = startOfTime == time ? nextDay : time
        return GanttScheduler.formatDate(displayDate, format: "EEE, MMM d")
    }
}
