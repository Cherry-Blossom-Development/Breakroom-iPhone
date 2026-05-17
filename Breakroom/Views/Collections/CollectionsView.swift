import SwiftUI

struct CollectionsView: View {
    @State private var collections: [Collection] = []
    @State private var isLoading = true
    @State private var error: String?

    // Create/Edit sheet
    @State private var showCreateSheet = false
    @State private var collectionToEdit: Collection?
    @State private var editName = ""
    @State private var editBackgroundColor = "#6366f1"

    // Delete confirmation
    @State private var collectionToDelete: Collection?
    @State private var showDeleteConfirmation = false

    @State private var isSaving = false

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
                        showCreateSheet = true
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
                Button {
                    editName = ""
                    editBackgroundColor = "#6366f1"
                    collectionToEdit = nil
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("collectionsAddButton")
            }
        }
        .task {
            await loadCollections()
        }
        .sheet(isPresented: $showCreateSheet) {
            collectionFormSheet
        }
        .sheet(item: $collectionToEdit) { collection in
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
    }

    // MARK: - Collections List

    private var collectionsList: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Store Setup section
                storeSetupSection

                // Collections section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Collections")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    ForEach(collections) { collection in
                        NavigationLink {
                            CollectionDetailView(collection: collection)
                        } label: {
                            CollectionCard(
                                collection: collection,
                                onEdit: {
                                    editName = collection.name
                                    editBackgroundColor = collection.settings?.backgroundColor ?? "#6366f1"
                                    collectionToEdit = collection
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
            .padding()
        }
        .accessibilityIdentifier("collectionsList")
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

    // MARK: - Form Sheet

    private var collectionFormSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Collection Name", text: $editName)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("collectionNameField")
                }

                Section("Background Color") {
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: editBackgroundColor) ?? .indigo },
                        set: { editBackgroundColor = $0.hexString }
                    ))
                    .accessibilityIdentifier("collectionColorPicker")
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
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func loadCollections() async {
        isLoading = true
        error = nil
        do {
            collections = try await CollectionsAPIService.getCollections()
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
                    backgroundColor: editBackgroundColor
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

    var body: some View {
        VStack(spacing: 0) {
            // Color preview
            backgroundColor
                .frame(height: 100)

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
