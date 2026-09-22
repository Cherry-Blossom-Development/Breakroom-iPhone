import SwiftUI

struct DiscoverView: View {
    // Section states with pagination
    @State private var showcaseSection = DiscoverSectionState<DiscoverStorefront>()
    @State private var gallerySection = DiscoverSectionState<DiscoverGallery>()
    @State private var blogSection = DiscoverSectionState<DiscoverBlog>()

    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var error: String?
    @State private var searchQuery = ""
    @State private var searchTask: Task<Void, Never>?

    // Navigation
    @State private var selectedStorefront: DiscoverStorefront?
    @State private var selectedGallery: DiscoverGallery?
    @State private var selectedBlog: DiscoverBlog?

    var body: some View {
        Group {
            if isLoading && !hasLoadedOnce {
                ProgressView("Loading...")
            } else if let error, !hasLoadedOnce {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadAll(reset: true) }
                    }
                    .accessibilityInputLabels(["retry", "try again", "reload"])
                }
            } else {
                discoverContent
            }
        }
        .navigationTitle("Discover")
        .task {
            await loadAll(reset: true)
        }
        .onChange(of: searchQuery) { _, newValue in
            // Debounce search - cancel previous and start new after 350ms
            searchTask?.cancel()
            searchTask = Task {
                do {
                    try await Task.sleep(for: .milliseconds(350))
                    await loadAll(reset: true)
                } catch {
                    // Task cancelled, ignore
                }
            }
        }
        .navigationDestination(item: $selectedStorefront) { storefront in
            PublicStorefrontView(storeUrl: storefront.storeUrl)
        }
        .navigationDestination(item: $selectedGallery) { gallery in
            PublicGalleryView(galleryUrl: gallery.galleryUrl)
        }
        .navigationDestination(item: $selectedBlog) { blog in
            PublicBlogView(blogUrl: blog.blogUrl)
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

                // Blogs Section
                blogsSection
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

            if showcaseSection.items.isEmpty {
                emptyState(
                    message: searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
                        ? "No showcases to discover yet."
                        : "No showcases match your search."
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(showcaseSection.items) { storefront in
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

                // Load More button
                if showcaseSection.hasMore {
                    loadMoreButton(isLoading: showcaseSection.isLoadingMore) {
                        Task { await loadMoreShowcases() }
                    }
                }
            }
        }
    }

    // MARK: - Galleries Section

    private var galleriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Galleries")
                .font(.title2.bold())
                .padding(.horizontal)

            if gallerySection.items.isEmpty {
                emptyState(
                    message: searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
                        ? "No galleries to discover yet."
                        : "No galleries match your search."
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(gallerySection.items) { gallery in
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

                // Load More button
                if gallerySection.hasMore {
                    loadMoreButton(isLoading: gallerySection.isLoadingMore) {
                        Task { await loadMoreGalleries() }
                    }
                }
            }
        }
    }

    // MARK: - Blogs Section

    private var blogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Blogs")
                .font(.title2.bold())
                .padding(.horizontal)

            if blogSection.items.isEmpty {
                emptyState(
                    message: searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
                        ? "No blogs to discover yet."
                        : "No blogs match your search."
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(blogSection.items) { blog in
                        DiscoverBlogCard(blog: blog)
                            .onTapGesture {
                                selectedBlog = blog
                            }
                    }
                }
                .padding(.horizontal)

                // Load More button
                if blogSection.hasMore {
                    loadMoreButton(isLoading: blogSection.isLoadingMore) {
                        Task { await loadMoreBlogs() }
                    }
                }
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

    private func loadMoreButton(isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Load More")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .disabled(isLoading)
        .padding(.horizontal)
    }

    // MARK: - Data Loading

    /// Load all sections, resetting each to page 1
    private func loadAll(reset: Bool) async {
        let showFullSpinner = !hasLoadedOnce
        if showFullSpinner {
            isLoading = true
        }
        error = nil

        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        let q: String? = query.isEmpty ? nil : query

        do {
            async let galleriesTask = DiscoverAPIService.getPublicGalleries(offset: 0, query: q)
            async let storefrontsTask = DiscoverAPIService.getPublicStorefronts(offset: 0, query: q)
            async let blogsTask = DiscoverAPIService.getPublicBlogs(offset: 0, query: q)

            let (galleriesResponse, storefrontsResponse, blogsResponse) = try await (galleriesTask, storefrontsTask, blogsTask)

            gallerySection = DiscoverSectionState(items: galleriesResponse.galleries, total: galleriesResponse.total)
            showcaseSection = DiscoverSectionState(items: storefrontsResponse.storefronts, total: storefrontsResponse.total)
            blogSection = DiscoverSectionState(items: blogsResponse.blogs, total: blogsResponse.total)
            hasLoadedOnce = true
        } catch {
            if !hasLoadedOnce {
                self.error = "Failed to load Discover content"
            }
        }

        isLoading = false
    }

    /// Load more showcases (next page)
    private func loadMoreShowcases() async {
        guard showcaseSection.hasMore && !showcaseSection.isLoadingMore else { return }
        showcaseSection.isLoadingMore = true

        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        let q: String? = query.isEmpty ? nil : query

        do {
            let response = try await DiscoverAPIService.getPublicStorefronts(
                offset: showcaseSection.items.count,
                query: q
            )
            showcaseSection.items.append(contentsOf: response.storefronts)
            showcaseSection.total = response.total
        } catch {
            // Non-fatal
        }
        showcaseSection.isLoadingMore = false
    }

    /// Load more galleries (next page)
    private func loadMoreGalleries() async {
        guard gallerySection.hasMore && !gallerySection.isLoadingMore else { return }
        gallerySection.isLoadingMore = true

        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        let q: String? = query.isEmpty ? nil : query

        do {
            let response = try await DiscoverAPIService.getPublicGalleries(
                offset: gallerySection.items.count,
                query: q
            )
            gallerySection.items.append(contentsOf: response.galleries)
            gallerySection.total = response.total
        } catch {
            // Non-fatal
        }
        gallerySection.isLoadingMore = false
    }

    /// Load more blogs (next page)
    private func loadMoreBlogs() async {
        guard blogSection.hasMore && !blogSection.isLoadingMore else { return }
        blogSection.isLoadingMore = true

        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        let q: String? = query.isEmpty ? nil : query

        do {
            let response = try await DiscoverAPIService.getPublicBlogs(
                offset: blogSection.items.count,
                query: q
            )
            blogSection.items.append(contentsOf: response.blogs)
            blogSection.total = response.total
        } catch {
            // Non-fatal
        }
        blogSection.isLoadingMore = false
    }
}

// MARK: - Discover Card

private struct DiscoverCard: View {
    let title: String
    let subtitle: String
    let artist: DiscoverArtist
    let coverImagePath: String?

    // Scale avatar size with Dynamic Type
    @ScaledMetric(relativeTo: .caption) private var avatarSize: CGFloat = 24
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                // Artist row - stack vertically for accessibility sizes
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        artistAvatar
                            .frame(width: avatarSize, height: avatarSize)
                            .clipShape(Circle())

                        Text(artist.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    HStack(spacing: 8) {
                        artistAvatar
                            .frame(width: avatarSize, height: avatarSize)
                            .clipShape(Circle())

                        Text(artist.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
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
                .font(.largeTitle)
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
                .font(.largeTitle)
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

// MARK: - Discover Blog Card

private struct DiscoverBlogCard: View {
    let blog: DiscoverBlog

    @ScaledMetric(relativeTo: .caption) private var avatarSize: CGFloat = 24
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var artistPhotoURL: URL? {
        guard let path = blog.artist.photoPath else { return nil }
        return URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(path)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Blog preview (shows latest post title/excerpt instead of cover image)
            blogPreview
                .aspectRatio(4/3, contentMode: .fit)
                .clipped()

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(blog.blogName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                // Artist row
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        artistAvatar
                            .frame(width: avatarSize, height: avatarSize)
                            .clipShape(Circle())

                        Text(blog.artist.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    HStack(spacing: 8) {
                        artistAvatar
                            .frame(width: avatarSize, height: avatarSize)
                            .clipShape(Circle())

                        Text(blog.artist.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text("\(blog.postCount) post\(blog.postCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var blogPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = blog.latestPostTitle {
                Text("Latest post")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .textCase(.uppercase)

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                if let excerpt = blog.latestPostExcerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            } else {
                Spacer()
                Text("No posts yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color(.tertiarySystemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
            Text(blog.artist.initial)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Public Blog View (placeholder for now)

struct PublicBlogView: View {
    let blogUrl: String

    var body: some View {
        // TODO: Implement full public blog view
        // For now, open in Safari
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Opening blog...")
                .font(.headline)

            Text("@\(blogUrl)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Blog")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let url = URL(string: "https://www.prosaurus.com/b/\(blogUrl)") {
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
