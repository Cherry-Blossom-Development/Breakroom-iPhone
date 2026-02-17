import SwiftUI

struct BreakroomView: View {
    @State private var viewModel = BreakroomViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading Breakroom...")
            } else if viewModel.blocks.isEmpty {
                emptyState
            } else {
                blockList
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        viewModel.showAddBlockSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        if viewModel.isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isRefreshing)
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddBlockSheet) {
            AddBlockSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadLayout()
        }
    }

    private var blockList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.blocks) { block in
                    BlockCard(
                        block: block,
                        isExpanded: viewModel.isExpanded(block.id),
                        onToggle: { viewModel.toggleBlock(block.id) },
                        onRemove: { Task { await viewModel.removeBlock(block.id) } }
                    )
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Blocks", systemImage: "square.grid.2x2")
        } description: {
            Text("Add widgets to customize your Breakroom.")
        } actions: {
            Button("Add Block") {
                viewModel.showAddBlockSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Block Card (Accordion Item)

struct BlockCard: View {
    let block: BreakroomBlock
    let isExpanded: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header - always visible, tappable to expand/collapse
            Button(action: onToggle) {
                HStack {
                    Image(systemName: block.type.systemImage)
                        .foregroundStyle(accentColor)
                        .frame(width: 24)

                    Text(block.displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(headerBackground)
            }
            .buttonStyle(.plain)

            // Content - visible when expanded
            if isExpanded {
                Divider()
                BlockWidgetView(block: block)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .confirmationDialog(
            "Remove \(block.displayTitle)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { onRemove() }
        }
    }

    private var accentColor: Color {
        switch block.type {
        case .chat: return .blue
        case .updates: return .orange
        case .calendar: return .purple
        case .weather: return .cyan
        case .news: return .red
        case .blog: return .green
        case .placeholder: return .gray
        }
    }

    private var headerBackground: Color {
        Color(.secondarySystemGroupedBackground)
    }
}

// MARK: - Add Block Sheet

struct AddBlockSheet: View {
    let viewModel: BreakroomViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: BlockType = .updates
    @State private var customTitle = ""
    @State private var isAdding = false

    // Chat room selection
    @State private var chatRooms: [ChatRoom] = []
    @State private var selectedRoomId: Int?
    @State private var isLoadingRooms = false

    // Rooms that are already added as blocks
    private var existingChatRoomIds: Set<Int> {
        Set(viewModel.blocks.compactMap { block in
            block.type == .chat ? block.contentId : nil
        })
    }

    // Available rooms (not yet on the page)
    private var availableRooms: [ChatRoom] {
        chatRooms.filter { !existingChatRoomIds.contains($0.id) }
    }

    private var canAdd: Bool {
        if selectedType == .chat {
            return selectedRoomId != nil
        }
        return true
    }

    var body: some View {
        NavigationStack {
            blockTypeList
                .navigationTitle("Add Block")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { sheetToolbar }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: selectedType) { _, newType in
            if newType == .chat && chatRooms.isEmpty {
                Task { await loadChatRooms() }
            }
        }
    }

    private var blockTypeList: some View {
        List {
            Section("Widget Type") {
                ForEach(BlockType.allCases) { type in
                    blockTypeRow(type)
                }
            }

            // Show chat room picker when chat is selected
            if selectedType == .chat {
                Section("Select Chat Room") {
                    if isLoadingRooms {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if availableRooms.isEmpty {
                        Text("All chat rooms are already on your page")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableRooms) { room in
                            Button {
                                selectedRoomId = room.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(room.name)
                                            .foregroundStyle(.primary)
                                        if let desc = room.description, !desc.isEmpty {
                                            Text(desc)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    if selectedRoomId == room.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Section("Title (Optional)") {
                TextField("Custom title", text: $customTitle)
            }
        }
    }

    private func blockTypeRow(_ type: BlockType) -> some View {
        Button {
            selectedType = type
            if type != .chat {
                selectedRoomId = nil
            }
        } label: {
            HStack {
                Image(systemName: type.systemImage)
                    .frame(width: 24)
                Text(type.defaultTitle)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedType == type {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private func loadChatRooms() async {
        isLoadingRooms = true
        do {
            chatRooms = try await ChatAPIService.getRooms()
        } catch {
            // Silently fail
        }
        isLoadingRooms = false
    }

    @ToolbarContentBuilder
    private var sheetToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
                isAdding = true
                Task {
                    await viewModel.addBlock(
                        type: selectedType,
                        title: customTitle.isEmpty ? nil : customTitle,
                        contentId: selectedRoomId
                    )
                    isAdding = false
                    dismiss()
                }
            }
            .disabled(isAdding || !canAdd)
        }
    }
}
