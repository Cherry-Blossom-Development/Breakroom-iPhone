import SwiftUI
import PhotosUI

// MARK: - Color Presets

let collectionColorPresets: [(hex: String, name: String)] = [
    ("#FFFFFF", "White"),
    ("#FEE2E2", "Red"),
    ("#FEF3C7", "Yellow"),
    ("#DCFCE7", "Green"),
    ("#DBEAFE", "Blue"),
    ("#EDE9FE", "Purple"),
    ("#FCE7F3", "Pink"),
    ("#F3F4F6", "Gray"),
    ("#1F2937", "Dark")
]

struct CollectionsView: View {
    @State private var collections: [Collection] = []
    @State private var isLoading = true
    @State private var error: String?

    // Create/Edit sheet
    @State private var showCreateSheet = false
    @State private var collectionToEdit: Collection?
    @State private var editName = ""
    @State private var editBackgroundColor = "#FFFFFF"
    @State private var editBackgroundType = "color"  // "color" or "image"
    @State private var editBackgroundImageData: Data?
    @State private var editBackgroundImagePath: String?  // Existing S3 path
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var collectionItems: [CollectionItem] = []  // For picking bg from items
    @State private var isLoadingItems = false

    // Delete confirmation
    @State private var collectionToDelete: Collection?
    @State private var showDeleteConfirmation = false

    // Reorder mode
    @State private var isReordering = false

    @State private var isSaving = false

    // Computed: should show background option (only when >1 collection will exist)
    private var shouldShowBackgroundOption: Bool {
        if collectionToEdit != nil {
            return collections.count > 1
        } else {
            return collections.count >= 1  // Creating new, so result will be >1
        }
    }

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading collections...")
                    .accessibilityIdentifier("collectionsLoading")
            } else if let error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadCollections() }
                    }
                    .accessibilityIdentifier("collectionsRetryButton")
                }
                .accessibilityIdentifier("collectionsError")
            } else if collections.isEmpty {
                ContentUnavailableView {
                    Label("No Showcases", systemImage: "square.stack.3d.up")
                } description: {
                    Text("Create your first showcase to start displaying your work.")
                } actions: {
                    Button("Create Showcase") {
                        prepareCreateSheet()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("collectionsCreateFirstButton")
                }
                .accessibilityIdentifier("collectionsEmpty")
            } else {
                collectionsList
            }
        }
        .accessibilityIdentifier("screenCollections")
        .navigationTitle("Artist Showcase")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    // Reorder button (only when >1 collections)
                    if collections.count > 1 {
                        Button {
                            if isReordering {
                                Task { await saveReorder() }
                            } else {
                                isReordering = true
                            }
                        } label: {
                            Text(isReordering ? "Done" : "Reorder")
                        }
                        .accessibilityIdentifier("collectionsReorderButton")
                    }

                    // Add button (hidden during reorder)
                    if !isReordering {
                        Button {
                            prepareCreateSheet()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityIdentifier("collectionsAddButton")
                    }
                }
            }
        }
        .task {
            await loadCollections()
        }
        .sheet(isPresented: $showCreateSheet) {
            collectionFormSheet
        }
        .sheet(item: $collectionToEdit) { _ in
            collectionFormSheet
        }
        .confirmationDialog(
            "Delete Collection?",
            isPresented: $showDeleteConfirmation,
            presenting: collectionToDelete
        ) { collection in
            Button("Delete \"\(collection.name)\"", role: .destructive) {
                Task { await deleteCollection(collection) }
            }
        } message: { collection in
            Text("This will permanently delete \"\(collection.name)\" and all its items. This cannot be undone.")
        }
        .onChange(of: selectedPhoto) {
            Task {
                if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                    editBackgroundImageData = data
                    editBackgroundImagePath = nil
                }
            }
        }
    }

    // MARK: - Collections List

    private var collectionsList: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Store Setup section (hidden during reorder)
                if !isReordering {
                    storeSetupSection
                }

                // Collections section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Collections")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    if isReordering {
                        reorderList
                    } else {
                        ForEach(collections) { collection in
                            NavigationLink {
                                CollectionDetailView(collection: collection, allCollections: collections)
                            } label: {
                                CollectionCard(
                                    collection: collection,
                                    onEdit: {
                                        prepareEditSheet(collection)
                                    },
                                    onDelete: {
                                        collectionToDelete = collection
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("collectionCard_\(collection.id)")
                        }
                    }
                }
            }
            .padding()
        }
        .accessibilityIdentifier("collectionsList")
    }

    // MARK: - Reorder List

    private var reorderList: some View {
        VStack(spacing: 8) {
            ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                HStack {
                    Text(collection.name)
                        .font(.headline)

                    Spacer()

                    // Up button
                    Button {
                        moveCollection(from: index, direction: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.title3)
                    }
                    .disabled(index == 0)
                    .buttonStyle(.bordered)

                    // Down button
                    Button {
                        moveCollection(from: index, direction: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                    }
                    .disabled(index == collections.count - 1)
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func moveCollection(from index: Int, direction: Int) {
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < collections.count else { return }
        collections.swapAt(index, newIndex)
    }

    private func saveReorder() async {
        let order = collections.map { $0.id }
        do {
            try await CollectionsAPIService.reorderCollections(order: order)
            isReordering = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Store Setup Section

    private var storeSetupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Store Setup")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                NavigationLink {
                    StorefrontSetupView()
                } label: {
                    SetupLinkRow(
                        icon: "storefront",
                        title: "Storefront",
                        description: "Set up your public store page"
                    )
                }

                NavigationLink {
                    PaymentSetupView()
                } label: {
                    SetupLinkRow(
                        icon: "creditcard",
                        title: "Payment Setup",
                        description: "Connect Stripe to receive payouts"
                    )
                }

                NavigationLink {
                    ShippingSetupView()
                } label: {
                    SetupLinkRow(
                        icon: "shippingbox",
                        title: "Shipping Setup",
                        description: "Configure shipping rates and destinations"
                    )
                }

                NavigationLink {
                    OrdersView()
                } label: {
                    SetupLinkRow(
                        icon: "doc.text",
                        title: "Orders",
                        description: "View and manage incoming orders from buyers"
                    )
                }
            }
        }
    }

    // MARK: - Form Sheet Helpers

    private func prepareCreateSheet() {
        editName = ""
        editBackgroundColor = "#FFFFFF"
        editBackgroundType = "color"
        editBackgroundImageData = nil
        editBackgroundImagePath = nil
        selectedPhoto = nil
        collectionItems = []
        collectionToEdit = nil
        showCreateSheet = true
    }

    private func prepareEditSheet(_ collection: Collection) {
        editName = collection.name
        editBackgroundColor = collection.settings?.backgroundColor ?? "#FFFFFF"
        editBackgroundType = collection.settings?.backgroundType ?? "color"
        editBackgroundImageData = nil
        editBackgroundImagePath = collection.settings?.backgroundImage
        selectedPhoto = nil
        collectionItems = []
        collectionToEdit = collection

        // Load items for background image picker
        Task {
            isLoadingItems = true
            do {
                collectionItems = try await CollectionsAPIService.getItems(collectionId: collection.id)
            } catch {
                // Ignore errors for item loading
            }
            isLoadingItems = false
        }
    }

    // MARK: - Form Sheet

    private var collectionFormSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Collection Name", text: $editName)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("collectionNameField")
                }

                // Background section (only show when >1 collection will exist)
                if shouldShowBackgroundOption {
                    Section("Background") {
                        // Type picker
                        Picker("Type", selection: $editBackgroundType) {
                            Text("Color").tag("color")
                            Text("Image").tag("image")
                        }
                        .pickerStyle(.segmented)

                        if editBackgroundType == "color" {
                            colorPresetPicker
                        } else {
                            imageBackgroundPicker
                        }
                    }
                }
            }
            .accessibilityIdentifier("collectionForm")
            .navigationTitle(collectionToEdit == nil ? "New Collection" : "Edit Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCreateSheet = false
                        collectionToEdit = nil
                    }
                    .accessibilityIdentifier("collectionCancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveCollection() }
                    }
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .accessibilityIdentifier("collectionSaveButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Color Preset Picker

    private var colorPresetPicker: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 44), spacing: 8)
        ], spacing: 8) {
            ForEach(collectionColorPresets, id: \.hex) { preset in
                Button {
                    editBackgroundColor = preset.hex
                } label: {
                    Circle()
                        .fill(Color(hex: preset.hex) ?? .white)
                        .frame(width: 44, height: 44)
                        .overlay {
                            if editBackgroundColor == preset.hex {
                                Image(systemName: "checkmark")
                                    .font(.headline.bold())
                                    .foregroundStyle(preset.hex == "#1F2937" ? .white : .black)
                            }
                        }
                        .overlay {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.name)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Image Background Picker

    private var imageBackgroundPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current image preview
            if let imageData = editBackgroundImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Remove Image", role: .destructive) {
                    editBackgroundImageData = nil
                    selectedPhoto = nil
                }
            } else if let imagePath = editBackgroundImagePath, !imagePath.isEmpty {
                CollectionItemImage(path: imagePath)
                    .frame(height: 100)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Remove Image", role: .destructive) {
                    editBackgroundImagePath = nil
                }
            }

            // Upload from photos
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Upload from Photos", systemImage: "photo.badge.plus")
            }

            // Pick from existing items
            if !collectionItems.isEmpty {
                Text("Or pick from items:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 60), spacing: 8)
                ], spacing: 8) {
                    ForEach(collectionItems.filter { $0.imagePath != nil }) { item in
                        Button {
                            editBackgroundImagePath = item.imagePath
                            editBackgroundImageData = nil
                            selectedPhoto = nil
                        } label: {
                            CollectionItemImage(path: item.imagePath!)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay {
                                    if editBackgroundImagePath == item.imagePath {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.accentColor, lineWidth: 3)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if isLoadingItems {
                ProgressView("Loading items...")
                    .font(.caption)
            }
        }
    }

    // MARK: - Actions

    private func loadCollections() async {
        isLoading = true
        error = nil
        do {
            collections = try await CollectionsAPIService.getCollections()
            // Sort by display_order
            collections.sort { ($0.displayOrder ?? 0) < ($1.displayOrder ?? 0) }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func saveCollection() async {
        let name = editName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isSaving = true
        do {
            if let existing = collectionToEdit {
                let updated = try await CollectionsAPIService.updateCollection(
                    id: existing.id,
                    name: name,
                    backgroundColor: editBackgroundType == "color" ? editBackgroundColor : nil,
                    backgroundType: shouldShowBackgroundOption ? editBackgroundType : nil,
                    backgroundImageData: editBackgroundType == "image" ? editBackgroundImageData : nil,
                    backgroundImagePath: editBackgroundType == "image" ? editBackgroundImagePath : nil
                )
                if let index = collections.firstIndex(where: { $0.id == existing.id }) {
                    collections[index] = updated
                }
            } else {
                let created = try await CollectionsAPIService.createCollection(
                    name: name,
                    backgroundColor: editBackgroundColor
                )
                collections.insert(created, at: 0)
            }
            showCreateSheet = false
            collectionToEdit = nil
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    private func deleteCollection(_ collection: Collection) async {
        do {
            try await CollectionsAPIService.deleteCollection(id: collection.id)
            collections.removeAll { $0.id == collection.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Setup Link Row

private struct SetupLinkRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Collection Card

private struct CollectionCard: View {
    let collection: Collection
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var backgroundColor: Color {
        if let hex = collection.settings?.backgroundColor {
            return Color(hex: hex) ?? .indigo
        }
        return .indigo
    }

    private var hasBackgroundImage: Bool {
        collection.settings?.backgroundType == "image" &&
        collection.settings?.backgroundImage != nil &&
        !(collection.settings?.backgroundImage?.isEmpty ?? true)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Background preview (color or image)
            ZStack {
                if hasBackgroundImage {
                    CollectionItemImage(path: collection.settings!.backgroundImage!)
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else {
                    backgroundColor
                        .frame(height: 100)
                }
            }

            // Info section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Manage items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.body)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.body)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Color Extensions

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

#Preview {
    CollectionsView()
}
