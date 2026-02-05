import SwiftUI
import PhotosUI

struct ArtGalleryView: View {
    @State private var settings: GallerySettings?
    @State private var artworks: [Artwork] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false

    // Settings editing
    @State private var showSettingsSheet = false

    // Upload
    @State private var showUploadSheet = false

    // Artwork management
    @State private var editingArtwork: Artwork?
    @State private var artworkToDelete: Artwork?
    @State private var showDeleteConfirm = false

    // Lightbox
    @State private var selectedArtwork: Artwork?

    private var publishedCount: Int {
        artworks.filter { $0.isPublishedBool }.count
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading gallery...")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Gallery Settings Card
                        settingsCard

                        // Artworks Section
                        artworksSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Art Gallery")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Upload", systemImage: "plus") {
                    showUploadSheet = true
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showSettingsSheet) {
            if let settings {
                GallerySettingsSheet(settings: settings) { updated in
                    self.settings = updated
                }
            } else {
                CreateGallerySheet { created in
                    self.settings = created
                }
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadArtworkSheet { newArtwork in
                artworks.insert(newArtwork, at: 0)
                // Auto-create settings if needed
                if settings == nil {
                    Task { await loadSettings() }
                }
            }
        }
        .sheet(item: $editingArtwork) { artwork in
            EditArtworkSheet(artwork: artwork) { updated in
                if let idx = artworks.firstIndex(where: { $0.id == updated.id }) {
                    artworks[idx] = updated
                }
            }
        }
        .fullScreenCover(item: $selectedArtwork) { artwork in
            ArtworkLightbox(artwork: artwork, artworks: artworks) { newSelection in
                selectedArtwork = newSelection
            }
        }
        .alert("Delete Artwork", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let artwork = artworkToDelete {
                    Task { await deleteArtwork(artwork) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let artwork = artworkToDelete {
                Text("Delete \"\(artwork.title)\"? This cannot be undone.")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Gallery Settings")
                    .font(.headline)
                Spacer()
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                }
            }

            if let settings {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Name", value: settings.galleryName)
                        .font(.subheadline)

                    HStack {
                        Text("Public URL")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("/g/\(settings.galleryUrl)")
                            .font(.subheadline.monospaced())
                        Button {
                            UIPasteboard.general.string = settings.publicUrl
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                    }
                }
            } else {
                Text("No gallery configured yet. Upload an artwork or configure settings to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Set Up Gallery") {
                    showSettingsSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Artworks Section

    private var artworksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Artworks")
                    .font(.headline)
                Spacer()
                Text("\(artworks.count) total, \(publishedCount) published")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if artworks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No artworks yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Upload Your First Artwork") {
                        showUploadSheet = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(artworks) { artwork in
                        artworkCard(artwork)
                    }
                }
            }
        }
    }

    private func artworkCard(_ artwork: Artwork) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            Button {
                selectedArtwork = artwork
            } label: {
                AsyncImage(url: artwork.imageURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color(.tertiarySystemFill))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minHeight: 120, maxHeight: 180)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color(.tertiarySystemFill))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.tertiary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Title and status
            HStack {
                Text(artwork.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Circle()
                    .fill(artwork.isPublishedBool ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }

            // Actions
            HStack(spacing: 12) {
                Button {
                    editingArtwork = artwork
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    artworkToDelete = artwork
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.8))
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }

    // MARK: - Data Loading

    private func loadData() async {
        await loadSettings()
        await loadArtworks()
        isLoading = false
    }

    private func loadSettings() async {
        do {
            settings = try await GalleryAPIService.getSettings()
        } catch {
            // Settings might not exist yet, that's okay
        }
    }

    private func loadArtworks() async {
        do {
            artworks = try await GalleryAPIService.getArtworks()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteArtwork(_ artwork: Artwork) async {
        do {
            try await GalleryAPIService.deleteArtwork(id: artwork.id)
            artworks.removeAll { $0.id == artwork.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Gallery Settings Sheet

struct GallerySettingsSheet: View {
    let settings: GallerySettings
    let onSave: (GallerySettings) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var galleryName: String
    @State private var galleryUrl: String
    @State private var urlAvailable: Bool? = nil
    @State private var isCheckingUrl = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(settings: GallerySettings, onSave: @escaping (GallerySettings) -> Void) {
        self.settings = settings
        self.onSave = onSave
        _galleryName = State(initialValue: settings.galleryName)
        _galleryUrl = State(initialValue: settings.galleryUrl)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gallery Info") {
                    TextField("Gallery Name", text: $galleryName)

                    HStack {
                        Text("/g/")
                            .foregroundStyle(.secondary)
                        TextField("url-slug", text: $galleryUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: galleryUrl) { _, _ in
                                checkUrlAvailability()
                            }
                        if isCheckingUrl {
                            ProgressView().controlSize(.small)
                        } else if let available = urlAvailable {
                            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(available ? .green : .red)
                        }
                    }
                }

                Section {
                    LabeledContent("Public URL") {
                        Text("\(APIClient.shared.baseURL)/g/\(galleryUrl)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Gallery Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(galleryName.isEmpty || galleryUrl.isEmpty || isSaving || urlAvailable == false)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func checkUrlAvailability() {
        guard galleryUrl != settings.galleryUrl else {
            urlAvailable = true
            return
        }

        isCheckingUrl = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            do {
                let result = try await GalleryAPIService.checkUrl(galleryUrl)
                urlAvailable = result.available || (result.isOwn ?? false)
            } catch {
                urlAvailable = nil
            }
            isCheckingUrl = false
        }
    }

    private func save() async {
        isSaving = true
        do {
            let updated = try await GalleryAPIService.updateSettings(
                galleryUrl: galleryUrl,
                galleryName: galleryName
            )
            onSave(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// MARK: - Create Gallery Sheet

struct CreateGallerySheet: View {
    let onCreate: (GallerySettings) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var galleryName = ""
    @State private var galleryUrl = ""
    @State private var urlAvailable: Bool? = nil
    @State private var isCheckingUrl = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Gallery Info") {
                    TextField("Gallery Name", text: $galleryName)

                    HStack {
                        Text("/g/")
                            .foregroundStyle(.secondary)
                        TextField("url-slug", text: $galleryUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: galleryUrl) { _, _ in
                                checkUrlAvailability()
                            }
                        if isCheckingUrl {
                            ProgressView().controlSize(.small)
                        } else if let available = urlAvailable {
                            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(available ? .green : .red)
                        }
                    }
                }

                Section {
                    Text("Your gallery URL will be shareable once you create it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await create() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(galleryName.isEmpty || galleryUrl.isEmpty || isSaving || urlAvailable == false)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func checkUrlAvailability() {
        guard !galleryUrl.isEmpty else {
            urlAvailable = nil
            return
        }

        isCheckingUrl = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            do {
                let result = try await GalleryAPIService.checkUrl(galleryUrl)
                urlAvailable = result.available
            } catch {
                urlAvailable = nil
            }
            isCheckingUrl = false
        }
    }

    private func create() async {
        isSaving = true
        do {
            let created = try await GalleryAPIService.createSettings(
                galleryUrl: galleryUrl,
                galleryName: galleryName
            )
            onCreate(created)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// MARK: - Upload Artwork Sheet

struct UploadArtworkSheet: View {
    let onUpload: (Artwork) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var title = ""
    @State private var description = ""
    @State private var isPublished = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Image") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let data = selectedImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("Select Image", systemImage: "photo.badge.plus")
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                selectedImageData = data
                            }
                        }
                    }
                }

                Section("Details") {
                    TextField("Title *", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Publish immediately", isOn: $isPublished)
                } footer: {
                    Text("Published artworks are visible on your public gallery.")
                }
            }
            .navigationTitle("Upload Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await upload() }
                    } label: {
                        if isUploading {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Upload")
                        }
                    }
                    .disabled(selectedImageData == nil || title.isEmpty || isUploading)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func upload() async {
        guard let imageData = selectedImageData else { return }

        isUploading = true

        // Determine mime type
        let mimeType: String
        let filename: String
        if let _ = UIImage(data: imageData)?.pngData() {
            mimeType = "image/jpeg" // Default to JPEG
            filename = "artwork.jpg"
        } else {
            mimeType = "image/jpeg"
            filename = "artwork.jpg"
        }

        do {
            let artwork = try await GalleryAPIService.uploadArtwork(
                imageData: imageData,
                filename: filename,
                mimeType: mimeType,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                isPublished: isPublished
            )
            onUpload(artwork)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isUploading = false
    }
}

// MARK: - Edit Artwork Sheet

struct EditArtworkSheet: View {
    let artwork: Artwork
    let onSave: (Artwork) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var isPublished: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    init(artwork: Artwork, onSave: @escaping (Artwork) -> Void) {
        self.artwork = artwork
        self.onSave = onSave
        _title = State(initialValue: artwork.title)
        _description = State(initialValue: artwork.description ?? "")
        _isPublished = State(initialValue: artwork.isPublishedBool)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preview") {
                    AsyncImage(url: artwork.imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        default:
                            Rectangle()
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                Section("Details") {
                    TextField("Title *", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Published", isOn: $isPublished)
                } footer: {
                    Text("Published artworks are visible on your public gallery.")
                }
            }
            .navigationTitle("Edit Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func save() async {
        isSaving = true
        do {
            let updated = try await GalleryAPIService.updateArtwork(
                id: artwork.id,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                isPublished: isPublished
            )
            onSave(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

// MARK: - Artwork Lightbox

struct ArtworkLightbox: View {
    let artwork: Artwork
    let artworks: [Artwork]
    let onNavigate: (Artwork?) -> Void

    @Environment(\.dismiss) private var dismiss

    private var currentIndex: Int {
        artworks.firstIndex(where: { $0.id == artwork.id }) ?? 0
    }

    private var hasPrevious: Bool {
        currentIndex > 0
    }

    private var hasNext: Bool {
        currentIndex < artworks.count - 1
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Image
            AsyncImage(url: artwork.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .empty:
                    ProgressView()
                        .tint(.white)
                default:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.width > 50 && hasPrevious {
                            onNavigate(artworks[currentIndex - 1])
                        } else if value.translation.width < -50 && hasNext {
                            onNavigate(artworks[currentIndex + 1])
                        }
                    }
            )

            // Overlay controls
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }
                    Spacer()
                    Text("\(currentIndex + 1) / \(artworks.count)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                }

                Spacer()

                // Title and description
                VStack(alignment: .leading, spacing: 8) {
                    Text(artwork.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let description = artwork.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial.opacity(0.8))

                // Navigation arrows
                HStack {
                    Button {
                        if hasPrevious {
                            onNavigate(artworks[currentIndex - 1])
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundStyle(.white.opacity(hasPrevious ? 1 : 0.3))
                            .frame(width: 60, height: 60)
                    }
                    .disabled(!hasPrevious)

                    Spacer()

                    Button {
                        if hasNext {
                            onNavigate(artworks[currentIndex + 1])
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title)
                            .foregroundStyle(.white.opacity(hasNext ? 1 : 0.3))
                            .frame(width: 60, height: 60)
                    }
                    .disabled(!hasNext)
                }
                .padding(.bottom)
            }
        }
    }
}
