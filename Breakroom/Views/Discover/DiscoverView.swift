import SwiftUI

struct DiscoverView: View {
    @State private var storefronts: [DiscoverStorefront] = []
    @State private var galleries: [DiscoverGallery] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var searchQuery = ""

    // Navigation
    @State private var selectedStorefront: DiscoverStorefront?
    @State private var selectedGallery: DiscoverGallery?

    private var filteredStorefronts: [DiscoverStorefront] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return storefronts }
        return storefronts.filter { storefront in
            storefront.displayTitle.lowercased().contains(query) ||
            storefront.artist.displayName.lowercased().contains(query) ||
            storefront.artist.handle.lowercased().contains(query)
        }
    }

    private var filteredGalleries: [DiscoverGallery] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return galleries }
        return galleries.filter { gallery in
            gallery.galleryName.lowercased().contains(query) ||
            gallery.artist.displayName.lowercased().contains(query) ||
            gallery.artist.handle.lowercased().contains(query)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadAll() }
                    }
                    .accessibilityInputLabels(["retry", "try again", "reload"])
                }
            } else {
                discoverContent
            }
        }
        .navigationTitle("Discover")
        .task {
            await loadAll()
        }
        .navigationDestination(item: $selectedStorefront) { storefront in
            PublicStorefrontView(storeUrl: storefront.storeUrl)
        }
        .navigationDestination(item: $selectedGallery) { gallery in
            PublicGalleryView(galleryUrl: gallery.galleryUrl)
        }
    }

    private var discoverContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search by name or artist...", text: $searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

                // Showcases Section
                showcasesSection

                // Galleries Section
                galleriesSection
            }
            .padding(.vertical)
        }
    }

    // MARK: - Showcases Section

    private var showcasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Showcases")
                .font(.title2.bold())
                .padding(.horizontal)

            if filteredStorefronts.isEmpty {
                emptyState(
                    message: storefronts.isEmpty
                        ? "No showcases to discover yet."
                        : "No showcases match your search."
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(filteredStorefronts) { storefront in
                        DiscoverCard(
                            title: storefront.displayTitle,
                            subtitle: "\(storefront.itemCount) item\(storefront.itemCount == 1 ? "" : "s")",
                            artist: storefront.artist,
                            coverImagePath: storefront.coverImagePath
                        )
                        .onTapGesture {
                            selectedStorefront = storefront
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Galleries Section

    private var galleriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Galleries")
                .font(.title2.bold())
                .padding(.horizontal)

            if filteredGalleries.isEmpty {
                emptyState(
                    message: galleries.isEmpty
                        ? "No galleries to discover yet."
                        : "No galleries match your search."
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(filteredGalleries) { gallery in
                        DiscoverCard(
                            title: gallery.galleryName,
                            subtitle: "\(gallery.artworkCount) artwork\(gallery.artworkCount == 1 ? "" : "s")",
                            artist: gallery.artist,
                            coverImagePath: gallery.coverImagePath
                        )
                        .onTapGesture {
                            selectedGallery = gallery
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }

    // MARK: - Data Loading

    private func loadAll() async {
        isLoading = true
        error = nil

        do {
            async let galleriesTask = DiscoverAPIService.getPublicGalleries()
            async let storefrontsTask = DiscoverAPIService.getPublicStorefronts()

            let (loadedGalleries, loadedStorefronts) = try await (galleriesTask, storefrontsTask)
            galleries = loadedGalleries
            storefronts = loadedStorefronts
        } catch {
            self.error = "Failed to load Discover content"
        }

        isLoading = false
    }
}

// MARK: - Discover Card

private struct DiscoverCard: View {
    let title: String
    let subtitle: String
    let artist: DiscoverArtist
    let coverImagePath: String?

    private var coverImageURL: URL? {
        guard let path = coverImagePath else { return nil }
        return URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(path)")
    }

    private var artistPhotoURL: URL? {
        guard let path = artist.photoPath else { return nil }
        return URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(path)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image
            coverImage
                .aspectRatio(4/3, contentMode: .fit)
                .clipped()

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                // Artist row
                HStack(spacing: 8) {
                    artistAvatar
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())

                    Text(artist.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var coverImage: some View {
        if let url = coverImageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    coverPlaceholder
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.tertiarySystemBackground))
                @unknown default:
                    coverPlaceholder
                }
            }
        } else {
            coverPlaceholder
        }
    }

    private var coverPlaceholder: some View {
        ZStack {
            Color(.tertiarySystemBackground)
            Text("No preview")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var artistAvatar: some View {
        if let url = artistPhotoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    avatarPlaceholder
                @unknown default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Color(.tertiarySystemFill)
            Text(artist.initial)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Public Storefront View (placeholder for now)

struct PublicStorefrontView: View {
    let storeUrl: String

    var body: some View {
        // TODO: Implement full public storefront view
        // For now, open in Safari
        VStack(spacing: 16) {
            Image(systemName: "storefront")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Opening storefront...")
                .font(.headline)

            Text("@\(storeUrl)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Showcase")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let url = URL(string: "https://www.prosaurus.com/store/\(storeUrl)") {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - Public Gallery View (placeholder for now)

struct PublicGalleryView: View {
    let galleryUrl: String

    var body: some View {
        // TODO: Implement full public gallery view
        // For now, open in Safari
        VStack(spacing: 16) {
            Image(systemName: "photo.artframe")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Opening gallery...")
                .font(.headline)

            Text("@\(galleryUrl)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let url = URL(string: "https://www.prosaurus.com/g/\(galleryUrl)") {
                UIApplication.shared.open(url)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DiscoverView()
    }
}
