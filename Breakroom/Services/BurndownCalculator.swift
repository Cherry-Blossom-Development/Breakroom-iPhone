import Foundation

/// Measures for burndown chart: count tickets or estimated work
enum BurndownMeasure: String, CaseIterable {
    case work = "Work"
    case tickets = "Tickets"
}

/// View mode for burndown: chart or table
enum BurndownViewMode: String, CaseIterable {
    case chart = "Chart"
    case table = "Table"
}

/// Sprint boundaries: start date to end date (exclusive)
struct SprintBounds {
    let index: Int
    let start: Date
    let end: Date // exclusive
}

/// A single day in the burndown chart
struct BurndownDay: Identifiable {
    let date: Date
    let end: Date
    let at: Date?          // nil for days that haven't begun
    let isToday: Bool
    let weekend: Bool
    let remaining: Double? // nil for days that haven't begun
    let ideal: Double
    let completed: Double
    let added: Double

    var id: Date { date }
}

/// Result of burndown calculation for a sprint
struct BurndownResult {
    let days: [BurndownDay]
    let startRemaining: Double
    let remaining: Double
    let idealNow: Double
    let completed: Double
    let added: Double
    let unestimatedCount: Int
    /// Days before any recorded history are reconstructed from resolved dates
    let approximate: Bool
    let started: Bool
    let finished: Bool
}

// Sprint burndown for one project. A port of web's
// frontend/src/utilities/burndown.js and Android's Burndown.kt; keep them in step.
//
// Rules:
//   - Sprints are back-to-back blocks of the project's sprint length
//     (Settings, migration 082), counted from the Monday of the week the
//     project was created.
//   - Remaining work at an instant = every ticket in the project that exists
//     by then and isn't resolved/closed then. Tickets added or reopened
//     mid-sprint push the line up; that's scope change, shown as "added".
//   - A ticket's status at any instant is replayed from status history
//     (migration 081). Before a ticket's first recorded change, its status is
//     that change's from_status; with no history at all, a done ticket counts
//     as done from its resolved_at.
//   - Work is measured in 8h working days (estimateWorkingHours); an
//     unestimated ticket counts as 1 day and is flagged. Estimates have no
//     history, so every day uses the ticket's current estimate.
//   - The ideal line runs from the sprint's starting remaining work to zero
//     at the sprint's end, dropping only on working days (Mon-Fri).

class BurndownCalculator {
    private let calendar: Calendar
    private let hoursPerDay: Double = 8.0

    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        self.calendar = cal
    }

    // MARK: - Date Parsing

    /// Parse an API date string (ISO 8601 format)
    func parseApiTime(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    // MARK: - Sprint Calculations

    /// Start of day for a date
    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Day of week (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    private func dayOfWeek(_ date: Date) -> Int {
        calendar.component(.weekday, from: date)
    }

    /// Add days to a date
    private func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Is this a weekend day?
    func isWeekend(_ date: Date) -> Bool {
        let weekday = dayOfWeek(date)
        return weekday == 1 || weekday == 7  // Sunday or Saturday
    }

    /// Monday on or before date, at midnight
    func sprintAnchor(_ date: Date) -> Date {
        let d = startOfDay(date)
        let weekday = dayOfWeek(d)
        // weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
        // Days to subtract to get to Monday
        let daysBack = (weekday == 1) ? 6 : (weekday - 2)
        return addDays(d, -daysBack)
    }

    /// Get sprint boundaries for a given index
    func sprintBounds(anchor: Date, sprintDays: Int, index: Int) -> SprintBounds {
        SprintBounds(
            index: index,
            start: addDays(anchor, index * sprintDays),
            end: addDays(anchor, (index + 1) * sprintDays)
        )
    }

    /// Index of the sprint containing date (never below 0)
    func sprintIndexAt(anchor: Date, sprintDays: Int, date: Date) -> Int {
        let startOfDate = startOfDay(date)
        let days = calendar.dateComponents([.day], from: anchor, to: startOfDate).day ?? 0
        return max(days / sprintDays, 0)
    }

    // MARK: - Working Hours

    /// Count working hours between two dates (8h per weekday)
    func workingHoursBetween(_ start: Date, _ end: Date) -> Double {
        var hours = 0.0
        var current = startOfDay(start)
        let endDay = startOfDay(end)

        while current < endDay {
            if !isWeekend(current) {
                hours += hoursPerDay
            }
            current = addDays(current, 1)
        }

        return hours
    }

    /// Convert ticket estimate to working hours (8h days)
    func estimateWorkingHours(amount: String?, unit: String?) -> Double? {
        guard let amountStr = amount,
              let amount = Double(amountStr),
              let unit = unit else { return nil }

        switch unit {
        case "hours":
            return amount
        case "days":
            return amount * hoursPerDay
        case "weeks":
            return amount * 5 * hoursPerDay  // 5 working days per week
        case "months":
            return amount * 20 * hoursPerDay  // ~20 working days per month
        default:
            return nil
        }
    }

    // MARK: - Status History

    private func isDone(_ status: String?) -> Bool {
        status == "resolved" || status == "closed"
    }

    private struct TimedChange {
        let change: TicketStatusChange
        let at: Date
    }

    /// Status a ticket had at instant t
    private func statusAt(ticket: BurndownTicket, changes: [TimedChange], t: Date) -> String {
        var last: TimedChange? = nil

        for c in changes {
            if c.at <= t {
                last = c
            } else {
                // First change after t: the ticket was in its from_status until then
                return last?.change.toStatus ?? c.change.fromStatus ?? c.change.toStatus
            }
        }

        if let last = last {
            return last.change.toStatus
        }

        // No recorded history (pre-migration 081): trust the current status,
        // but a done ticket was only done from when it was resolved
        if isDone(ticket.status) {
            let doneAt = parseApiTime(ticket.resolvedAt ?? ticket.updatedAt ?? ticket.createdAt) ?? Date.distantPast
            return doneAt <= t ? ticket.status : "backlog"
        }

        return ticket.status
    }

    // MARK: - Burndown Calculation

    private struct SizedTicket {
        let ticket: BurndownTicket
        let createdAt: Date
        let changes: [TimedChange]
        let unestimated: Bool
        let size: Double
    }

    /// Build burndown result for a sprint
    func build(
        tickets: [BurndownTicket],
        history: [TicketStatusChange],
        start: Date,
        end: Date,
        now: Date,
        measure: BurndownMeasure
    ) -> BurndownResult {
        // Parse and group history by ticket
        let timed: [TimedChange] = history.compactMap { change in
            guard let at = parseApiTime(change.changedAt) else { return nil }
            return TimedChange(change: change, at: at)
        }
        let changesByTicket = Dictionary(grouping: timed) { $0.change.ticketId }

        // Size each ticket
        let sized: [SizedTicket] = tickets.map { t in
            let hours = estimateWorkingHours(amount: t.estimateAmount, unit: t.estimateUnit)
            return SizedTicket(
                ticket: t,
                createdAt: parseApiTime(t.createdAt) ?? Date.distantPast,
                changes: changesByTicket[t.id] ?? [],
                unestimated: hours == nil,
                // Size in the chart's unit: working days, or 1 per ticket
                size: measure == .tickets ? 1.0 : (hours ?? hoursPerDay) / hoursPerDay
            )
        }

        func exists(_ s: SizedTicket, _ t: Date) -> Bool {
            s.createdAt <= t
        }

        func openAt(_ s: SizedTicket, _ t: Date) -> Bool {
            exists(s, t) && !isDone(statusAt(ticket: s.ticket, changes: s.changes, t: t))
        }

        func remainingAt(_ t: Date) -> Double {
            sized.reduce(0) { acc, s in acc + (openAt(s, t) ? s.size : 0) }
        }

        let startRemaining = remainingAt(start)
        let totalWorking = workingHoursBetween(start, end)

        func idealAt(_ t: Date) -> Double {
            if totalWorking > 0 {
                return startRemaining * max(0, 1 - workingHoursBetween(start, t) / totalWorking)
            }
            return 0
        }

        var days: [BurndownDay] = []
        var dayStart = start

        while dayStart < end {
            let dayEnd = addDays(dayStart, 1)
            let started = dayStart <= now
            let at = dayEnd < now ? dayEnd : now  // today: as of now

            var completed = 0.0
            var added = 0.0

            if started {
                for s in sized {
                    let wasOpen = openAt(s, dayStart)
                    let isOpen = openAt(s, at)
                    let createdToday = !exists(s, dayStart) && exists(s, at)

                    if createdToday {
                        added += s.size
                        if !isOpen {
                            completed += s.size  // created and finished the same day
                        }
                    } else if wasOpen && !isOpen {
                        completed += s.size
                    } else if !wasOpen && isOpen {
                        added += s.size  // reopened
                    }
                }
            }

            days.append(BurndownDay(
                date: dayStart,
                end: dayEnd,
                at: started ? at : nil,
                isToday: dayStart <= now && now < dayEnd,
                weekend: isWeekend(dayStart),
                remaining: started ? remainingAt(at) : nil,
                ideal: idealAt(dayEnd),
                completed: completed,
                added: added
            ))

            dayStart = dayEnd
        }

        let latest = days.last { $0.remaining != nil }
        let current = latest?.remaining ?? startRemaining

        // This sprint's work: tickets that exist by now and weren't already
        // done when it started
        let until = latest?.at ?? start
        let inScope = sized.filter { exists($0, until) && (!exists($0, start) || openAt($0, start)) }
        let earliestHistory = timed.first?.at

        return BurndownResult(
            days: days,
            startRemaining: startRemaining,
            remaining: current,
            idealNow: latest?.at.map { idealAt($0) } ?? startRemaining,
            completed: days.reduce(0) { $0 + $1.completed },
            added: days.reduce(0) { $0 + $1.added },
            unestimatedCount: measure == .work ? inScope.filter { $0.unestimated }.count : 0,
            approximate: earliestHistory == nil || start < (earliestHistory ?? Date.distantPast),
            started: start <= now,
            finished: end <= now
        )
    }
}

// MARK: - Formatting Helpers

extension BurndownCalculator {
    static func round1(_ n: Double) -> Double {
        (n * 10).rounded() / 10
    }

    static func num(_ n: Double) -> String {
        let rounded = round1(n)
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(rounded)
    }

    static func formatAmount(_ n: Double?, measure: BurndownMeasure) -> String {
        guard let n = n else { return "—" }
        let v = round1(n)
        let unit = measure == .tickets ? "ticket" : "day"
        return "\(num(v)) \(unit)\(v == 1.0 ? "" : "s")"
    }

    static func formatShort(_ n: Double, measure: BurndownMeasure) -> String {
        measure == .tickets ? num(n) : "\(num(n))d"
    }

    static func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
