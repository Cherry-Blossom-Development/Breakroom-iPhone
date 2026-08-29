import SwiftUI

struct ToolShedView: View {
    @State private var shortcuts: Set<String> = []
    @State private var isLoadingShortcuts = true

    // Scale icon sizes with Dynamic Type
    @ScaledMetric(relativeTo: .body) private var toolIconSize: CGFloat = 40
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Intro
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to the Tool Shed")
                        .font(.title2.bold())
                    Text("A collection of optional tools to help with your creative and professional work. Add your favorites for quick access.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Tool Categories
                ForEach(ToolCategory.visibleCases, id: \.self) { category in
                    toolCategorySection(category)
                }

                // Feedback
                VStack(alignment: .leading, spacing: 8) {
                    Text("Have a tool idea?")
                        .font(.headline)
                    Text("We're always looking to add useful tools. Submit your suggestions through the Help Desk.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .accessibilityIdentifier("screenToolShed")
        .navigationTitle("Tool Shed")
        .navigationDestination(for: ToolDestination.self) { destination in
            destinationView(destination)
        }
        .task {
            await loadShortcuts()
        }
    }

    @ViewBuilder
    private func toolCategorySection(_ category: ToolCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundStyle(category.color)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.headline)
                    Text(category.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Tools in category
            ForEach(category.tools, id: \.name) { tool in
                toolCard(tool, category: category)
            }
        }
    }

    private func toolCard(_ tool: Tool, category: ToolCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: tool.icon)
                    .font(.title2)
                    .foregroundStyle(category.color)
                    .frame(width: toolIconSize, height: toolIconSize)
                    .background(category.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.name)
                        .font(.body.weight(.semibold))
                    Text(tool.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                NavigationLink(value: tool.destination) {
                    Label("Open", systemImage: "arrow.right.circle")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(category.color)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityIdentifier("\(tool.name.lowercased().replacingOccurrences(of: " ", with: ""))OpenButton")
                .accessibilityInputLabels(["open", "open \(tool.name.lowercased())", "go to \(tool.name.lowercased())"])

                if shortcuts.contains(tool.shortcutUrl) {
                    Label("In Shortcuts", systemImage: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task { await addShortcut(tool) }
                    } label: {
                        Label("Add to Shortcuts", systemImage: "plus")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemFill))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .accessibilityInputLabels(["add shortcut", "add to shortcuts", "favorite"])
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func destinationView(_ destination: ToolDestination) -> some View {
        switch destination {
        case .lyricLab:
            LyricLabView()
        case .sessions:
            SessionsView()
        case .artGallery:
            ArtGalleryView()
        case .collections:
            CollectionsView()
        case .blog:
            BlogManagementView()
        case .kanban:
            KanbanRedirectView()
        case .games:
            GamesView()
        }
    }

    private func loadShortcuts() async {
        do {
            let result = try await ShortcutsAPIService.getShortcuts()
            shortcuts = Set(result.map { $0.url })
            isLoadingShortcuts = false
        } catch {
            isLoadingShortcuts = false
        }
    }

    private func addShortcut(_ tool: Tool) async {
        do {
            _ = try await ShortcutsAPIService.addShortcut(name: tool.name, url: tool.shortcutUrl)
            shortcuts.insert(tool.shortcutUrl)
        } catch {
            // Silently fail - shortcut might already exist
        }
    }
}

// MARK: - Tool Data

enum ToolDestination: Hashable {
    case lyricLab
    case sessions
    case artGallery
    case collections
    case blog
    case kanban
    case games
}

struct Tool {
    let name: String
    let description: String
    let icon: String
    let destination: ToolDestination
    let shortcutUrl: String
}

enum ToolCategory: CaseIterable {
    case musician
    case artist
    case writer
    case developer
    case games

    /// Categories visible to the current user (games requires feature flag).
    @MainActor
    static var visibleCases: [ToolCategory] {
        var cases: [ToolCategory] = [.musician, .artist, .writer, .developer]
        if FeaturesStore.shared.has("games") {
            cases.append(.games)
        }
        return cases
    }

    var title: String {
        switch self {
        case .musician: return "Musician Tools"
        case .artist: return "Artist Tools"
        case .writer: return "Writer Tools"
        case .developer: return "Developer Tools"
        case .games: return "Games"
        }
    }

    var subtitle: String {
        switch self {
        case .musician: return "For songwriters and musicians"
        case .artist: return "For visual artists"
        case .writer: return "For writers and bloggers"
        case .developer: return "For developers and project managers"
        case .games: return "Text-based space exploration"
        }
    }

    var icon: String {
        switch self {
        case .musician: return "music.note"
        case .artist: return "paintpalette"
        case .writer: return "pencil.line"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .games: return "gamecontroller"
        }
    }

    var color: Color {
        switch self {
        case .musician: return .purple
        case .artist: return .pink
        case .writer: return .orange
        case .developer: return .blue
        case .games: return .green
        }
    }

    var tools: [Tool] {
        switch self {
        case .musician:
            return [
                Tool(
                    name: "Lyric Lab",
                    description: "Capture lyric ideas, organize them into songs, and collaborate with other songwriters.",
                    icon: "music.mic",
                    destination: .lyricLab,
                    shortcutUrl: "/lyrics"
                ),
                Tool(
                    name: "Sessions",
                    description: "Track and manage your recording sessions, log progress, and keep notes on each session.",
                    icon: "music.note",
                    destination: .sessions,
                    shortcutUrl: "/sessions"
                )
            ]
        case .artist:
            return [
                Tool(
                    name: "Art Gallery",
                    description: "Upload and display artwork in a personal gallery with a shareable public URL.",
                    icon: "photo.artframe",
                    destination: .artGallery,
                    shortcutUrl: "/art-gallery"
                ),
                Tool(
                    name: "Artist Showcase",
                    description: "Create and manage collections of your work for sale. Set prices, availability, and shipping details.",
                    icon: "square.stack.3d.up",
                    destination: .collections,
                    shortcutUrl: "/collections"
                )
            ]
        case .writer:
            return [
                Tool(
                    name: "Blog",
                    description: "Create and publish blog posts to share your thoughts with the world.",
                    icon: "doc.richtext",
                    destination: .blog,
                    shortcutUrl: "/blog"
                )
            ]
        case .developer:
            return [
                Tool(
                    name: "Kanban",
                    description: "Organize projects with a visual kanban board for tracking tasks and progress.",
                    icon: "rectangle.split.3x1",
                    destination: .kanban,
                    shortcutUrl: "/kanban"
                )
            ]
        case .games:
            return [
                Tool(
                    name: "Haulonaut",
                    description: "A text-based space exploration game. Haul cargo across 1000-sector universes and make your fortune.",
                    icon: "sparkles",
                    destination: .games,
                    shortcutUrl: "/games"
                )
            ]
        }
    }
}
