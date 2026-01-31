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
            WeatherWidgetPlaceholder(block: block)
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

struct WeatherWidgetPlaceholder: View {
    let block: BreakroomBlock

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.sun")
                .font(.largeTitle)
                .foregroundStyle(.cyan)

            Text("Weather widget coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.1), .cyan.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
