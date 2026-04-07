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
                    if viewModel.isEditMode {
                        Button("Done") {
                            Task {
                                await viewModel.saveBlockOrder()
                                withAnimation {
                                    viewModel.isEditMode = false
                                }
                            }
                        }
                        .fontWeight(.semibold)
                    } else {
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
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddBlockSheet, onDismiss: {
            // Force refresh to ensure new block appears
            Task { await viewModel.refresh() }
        }) {
            AddBlockSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadLayout()
        }
        .navigationDestination(for: BlogPost.self) { post in
            BlogPostView(post: post)
        }
        .navigationDestination(for: String.self) { handle in
            PublicProfileView(handle: handle)
        }
    }

    private var blockList: some View {
        List {
            ForEach(viewModel.blocks) { block in
                BlockCard(
                    block: block,
                    isExpanded: viewModel.isExpanded(block.id),
                    isEditMode: viewModel.isEditMode,
                    onToggle: { viewModel.toggleBlock(block.id) },
                    onRemove: { Task { await viewModel.removeBlock(block.id) } },
                    onEnterEditMode: {
                        withAnimation {
                            viewModel.isEditMode = true
                        }
                    }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
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
    let isEditMode: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    let onEnterEditMode: () -> Void
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header - always visible, tappable to expand/collapse
            HStack {
                Image(systemName: block.type?.systemImage ?? "square")
                    .foregroundStyle(accentColor)
                    .frame(width: 24)

                Text(block.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if !isEditMode {
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(headerBackground)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditMode {
                    onToggle()
                }
            }
            .contextMenu {
                if !isEditMode {
                    Button {
                        onEnterEditMode()
                    } label: {
                        Label("Rearrange Widgets", systemImage: "arrow.up.arrow.down")
                    }
                }
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Remove Widget", systemImage: "trash")
                }
            }
            .accessibilityIdentifier("blockCard_\(block.displayTitle)")

            // Content - visible when expanded and not in edit mode
            if isExpanded && !isEditMode {
                Divider()
                BlockWidgetView(block: block)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEditMode ? Color.accentColor.opacity(0.5) : Color(.quaternaryLabel), lineWidth: isEditMode ? 2 : 1)
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
        case .none: return .gray
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
    @State private var myRoomIds: Set<Int> = []  // Rooms user is already a member of
    @State private var selectedRoomId: Int?
    @State private var isLoadingRooms = false
    @State private var roomLoadError: String?

    // Block types already on the page (excluding chat, which allows multiples)
    private var existingBlockTypes: Set<BlockType> {
        Set(viewModel.blocks.compactMap { $0.type }.filter { $0 != .chat })
    }

    // Available block types (filter out singles that are already added)
    private var availableBlockTypes: [BlockType] {
        BlockType.allCases.filter { type in
            type == .chat || !existingBlockTypes.contains(type)
        }
    }

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

    // Get the selected room object
    private var selectedRoom: ChatRoom? {
        guard let id = selectedRoomId else { return nil }
        return chatRooms.first { $0.id == id }
    }

    private var canAdd: Bool {
        guard !availableBlockTypes.isEmpty else { return false }
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
        .onAppear {
            // Select first available type if current selection isn't available
            if !availableBlockTypes.contains(selectedType),
               let firstAvailable = availableBlockTypes.first {
                selectedType = firstAvailable
            }
        }
        .onChange(of: selectedType) { _, newType in
            if newType == .chat && chatRooms.isEmpty {
                Task { await loadChatRooms() }
            }
        }
    }

    private var blockTypeList: some View {
        List {
            Section("Widget Type") {
                if availableBlockTypes.isEmpty {
                    Text("All widget types are already on your page")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableBlockTypes) { type in
                        blockTypeRow(type)
                    }
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
                    } else if let error = roomLoadError {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Failed to load chat rooms")
                                .foregroundStyle(.secondary)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                            Button("Retry") {
                                Task { await loadChatRooms() }
                            }
                            .font(.caption)
                        }
                    } else if chatRooms.isEmpty {
                        Text("You don't have any chat rooms. Join or create a chat room first.")
                            .foregroundStyle(.secondary)
                    } else if availableRooms.isEmpty {
                        Text("All your chat rooms are already on this page")
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
        roomLoadError = nil
        do {
            // Load both user's rooms and discoverable rooms
            async let myRoomsTask = ChatAPIService.getRooms()
            async let discoverableRoomsTask = ChatAPIService.getDiscoverableRooms()

            let (userRooms, publicRooms) = try await (myRoomsTask, discoverableRoomsTask)

            // Track which rooms user is already a member of
            myRoomIds = Set(userRooms.map { $0.id })

            // Combine and deduplicate (user's rooms take precedence)
            var roomsById: [Int: ChatRoom] = [:]
            for room in publicRooms {
                roomsById[room.id] = room
            }
            for room in userRooms {
                roomsById[room.id] = room
            }
            chatRooms = Array(roomsById.values).sorted { $0.name < $1.name }
        } catch {
            roomLoadError = error.localizedDescription
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
                    // For chat widgets, handle room joining and title
                    if selectedType == .chat, let roomId = selectedRoomId {
                        // If user isn't a member, join the room first
                        if !myRoomIds.contains(roomId) {
                            _ = try? await ChatAPIService.joinRoom(id: roomId)
                        }
                        // Use room name as title if no custom title provided
                        let title = customTitle.isEmpty ? selectedRoom?.name : customTitle
                        await viewModel.addBlock(
                            type: selectedType,
                            title: title,
                            contentId: roomId
                        )
                    } else {
                        await viewModel.addBlock(
                            type: selectedType,
                            title: customTitle.isEmpty ? nil : customTitle,
                            contentId: selectedRoomId
                        )
                    }
                    isAdding = false
                    dismiss()
                }
            }
            .disabled(isAdding || !canAdd)
        }
    }
}
