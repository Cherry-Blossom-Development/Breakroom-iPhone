import SwiftUI
import PhotosUI

struct CollectionDetailView: View {
    let collection: Collection

    @State private var items: [CollectionItem] = []
    @State private var isLoading = true
    @State private var error: String?

    // Create/Edit sheet
    @State private var showItemSheet = false
    @State private var itemToEdit: CollectionItem?

    // Delete confirmation
    @State private var itemToDelete: CollectionItem?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading items...")
            } else if let error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadItems() }
                    }
                }
            } else if items.isEmpty {
                ContentUnavailableView {
                    Label("No Items", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Add items to your collection to start selling.")
                } actions: {
                    Button("Add Item") {
                        itemToEdit = nil
                        showItemSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                itemsGrid
            }
        }
        .navigationTitle(collection.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    itemToEdit = nil
                    showItemSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await loadItems()
        }
        .sheet(isPresented: $showItemSheet) {
            ItemFormSheet(
                collectionId: collection.id,
                item: itemToEdit,
                onSave: { savedItem in
                    if let existing = itemToEdit,
                       let index = items.firstIndex(where: { $0.id == existing.id }) {
                        items[index] = savedItem
                    } else {
                        items.append(savedItem)
                    }
                    showItemSheet = false
                    itemToEdit = nil
                },
                onCancel: {
                    showItemSheet = false
                    itemToEdit = nil
                }
            )
        }
        .confirmationDialog(
            "Delete Item?",
            isPresented: $showDeleteConfirmation,
            presenting: itemToDelete
        ) { item in
            Button("Delete \"\(item.name)\"", role: .destructive) {
                Task { await deleteItem(item) }
            }
        } message: { item in
            Text("This will permanently delete \"\(item.name)\". This cannot be undone.")
        }
    }

    // MARK: - Items Grid

    private var itemsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(items) { item in
                    ItemCard(
                        item: item,
                        onEdit: {
                            itemToEdit = item
                            showItemSheet = true
                        },
                        onDelete: {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func loadItems() async {
        isLoading = true
        error = nil
        do {
            items = try await CollectionsAPIService.getItems(collectionId: collection.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteItem(_ item: CollectionItem) async {
        do {
            try await CollectionsAPIService.deleteItem(collectionId: collection.id, itemId: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Item Card

private struct ItemCard: View {
    let item: CollectionItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            if let imagePath = item.imagePath, !imagePath.isEmpty {
                CollectionItemImage(path: imagePath)
                    .aspectRatio(4/3, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(4/3, contentMode: .fill)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer()

                    // Availability badge
                    Text(item.isListed ? "Listed" : "Unlisted")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.isListed ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundStyle(item.isListed ? .green : .secondary)
                        .clipShape(Capsule())
                }

                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    if let price = item.priceFormatted {
                        Text(price)
                            .font(.subheadline.weight(.bold))
                    } else {
                        Text("No price")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let shipping = item.shippingCostFormatted {
                        Text(shipping)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        onEdit()
                    } label: {
                        Text("Edit")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Text("Delete")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(10)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
    }
}

// MARK: - Item Form Sheet

private struct ItemFormSheet: View {
    let collectionId: Int
    let item: CollectionItem?
    let onSave: (CollectionItem) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var priceString = ""
    @State private var isAvailable = false
    @State private var shippingCostString = ""
    @State private var weightString = ""
    @State private var lengthString = ""
    @State private var widthString = ""
    @State private var heightString = ""

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var existingImagePath: String?

    @State private var isSaving = false
    @State private var error: String?

    private var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section("Basic Info") {
                    TextField("Item Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Image
                Section("Image") {
                    if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("Remove Image", role: .destructive) {
                            selectedImageData = nil
                            selectedPhoto = nil
                        }
                    } else if let existingPath = existingImagePath, !existingPath.isEmpty {
                        CollectionItemImage(path: existingPath)
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Replace Image")
                        }
                    } else {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Add Image")
                            }
                        }
                    }
                }

                // Pricing
                Section("Pricing") {
                    HStack {
                        Text("$")
                        TextField("Price", text: $priceString)
                            .keyboardType(.decimalPad)
                    }

                    Toggle("Listed for sale", isOn: $isAvailable)
                }

                // Shipping
                Section("Shipping") {
                    HStack {
                        Text("$")
                        TextField("Shipping cost (optional)", text: $shippingCostString)
                            .keyboardType(.decimalPad)
                    }

                    HStack {
                        TextField("Weight", text: $weightString)
                            .keyboardType(.decimalPad)
                        Text("oz")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        VStack {
                            Text("L")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("", text: $lengthString)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack {
                            Text("W")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("", text: $widthString)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack {
                            Text("H")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("", text: $heightString)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        Text("in")
                            .foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                        existingImagePath = nil
                    }
                }
            }
            .onAppear {
                if let item {
                    name = item.name
                    description = item.description ?? ""
                    if let cents = item.priceCents {
                        priceString = String(format: "%.2f", Double(cents) / 100.0)
                    }
                    isAvailable = item.isAvailable ?? false
                    if let cents = item.shippingCostCents {
                        shippingCostString = String(format: "%.2f", Double(cents) / 100.0)
                    }
                    if let weight = item.weightOz {
                        weightString = String(weight)
                    }
                    if let length = item.lengthIn {
                        lengthString = String(length)
                    }
                    if let width = item.widthIn {
                        widthString = String(width)
                    }
                    if let height = item.heightIn {
                        heightString = String(height)
                    }
                    existingImagePath = item.imagePath
                }
            }
        }
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        isSaving = true
        error = nil

        let priceCents = priceString.isEmpty ? nil : Int((Double(priceString) ?? 0) * 100)
        let shippingCents = shippingCostString.isEmpty ? nil : Int((Double(shippingCostString) ?? 0) * 100)
        let weight = weightString.isEmpty ? nil : Double(weightString)
        let length = lengthString.isEmpty ? nil : Double(lengthString)
        let width = widthString.isEmpty ? nil : Double(widthString)
        let height = heightString.isEmpty ? nil : Double(heightString)

        do {
            let savedItem: CollectionItem
            if let existingItem = item {
                savedItem = try await CollectionsAPIService.updateItem(
                    collectionId: collectionId,
                    itemId: existingItem.id,
                    name: trimmedName,
                    description: description.isEmpty ? nil : description,
                    imageData: selectedImageData,
                    priceCents: priceCents,
                    isAvailable: isAvailable,
                    shippingCostCents: shippingCents,
                    weightOz: weight,
                    lengthIn: length,
                    widthIn: width,
                    heightIn: height
                )
            } else {
                savedItem = try await CollectionsAPIService.createItem(
                    collectionId: collectionId,
                    name: trimmedName,
                    description: description.isEmpty ? nil : description,
                    imageData: selectedImageData,
                    priceCents: priceCents,
                    isAvailable: isAvailable,
                    shippingCostCents: shippingCents,
                    weightOz: weight,
                    lengthIn: length,
                    widthIn: width,
                    heightIn: height
                )
            }
            onSave(savedItem)
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Collection Item Image

struct CollectionItemImage: View {
    let path: String

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if failed {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task(id: path) {
            await load()
        }
    }

    private func load() async {
        guard let url = URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(path)") else {
            failed = true
            return
        }

        var request = URLRequest(url: url)
        if let token = KeychainManager.bearerToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let uiImage = UIImage(data: data) {
                self.image = uiImage
            } else {
                failed = true
            }
        } catch {
            failed = true
        }
    }
}

#Preview {
    NavigationStack {
        CollectionDetailView(collection: Collection(
            id: 1,
            userId: 1,
            name: "Test Collection",
            settings: nil,
            createdAt: nil,
            updatedAt: nil
        ))
    }
}
