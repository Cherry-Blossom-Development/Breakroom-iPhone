import SwiftUI

struct BlogManagementView: View {
    @State private var posts: [BlogPost] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSettings = false
    @State private var postToDelete: BlogPost?
    @State private var showDeleteConfirmation = false
    @State private var editingPost: BlogPost?

    private var isEditing: Binding<Bool> {
        Binding(
            get: { editingPost != nil },
            set: { if !$0 { editingPost = nil } }
        )
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if posts.isEmpty {
                ContentUnavailableView(
                    "No Posts Yet",
                    systemImage: "doc.richtext",
                    description: Text("Tap + to write your first blog post.")
                )
            } else {
                postList
            }
        }
        .navigationTitle("My Blog")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }

                    NavigationLink {
                        BlogEditorView(existingPost: nil, onSave: handleSave)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            BlogSettingsView()
        }
        .navigationDestination(isPresented: isEditing) {
            if let post = editingPost {
                BlogEditorView(existingPost: post, onSave: handleSave)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .confirmationDialog(
            "Delete Post",
            isPresented: $showDeleteConfirmation,
            presenting: postToDelete
        ) { post in
            Button("Delete", role: .destructive) {
                Task { await deletePost(post) }
            }
        } message: { post in
            Text("Are you sure you want to delete \"\(post.title)\"?")
        }
        .refreshable {
            await loadPosts()
        }
        .task {
            await loadPosts()
        }
    }

    private var postList: some View {
        List {
            ForEach(posts) { post in
                Button {
                    editingPost = post
                } label: {
                    postRow(post)
                }
                .foregroundStyle(.primary)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        postToDelete = post
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func postRow(_ post: BlogPost) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(post.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text((post.isPublished ?? 0) != 0 ? "Published" : "Draft")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (post.isPublished ?? 0) != 0
                                ? Color.green.opacity(0.15)
                                : Color.secondary.opacity(0.15)
                        )
                        .foregroundStyle(
                            (post.isPublished ?? 0) != 0 ? .green : .secondary
                        )
                        .clipShape(Capsule())
                }

                if !post.plainTextPreview.isEmpty {
                    Text(post.plainTextPreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(post.relativeDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func handleSave(_ savedPost: BlogPost) {
        if let index = posts.firstIndex(where: { $0.id == savedPost.id }) {
            posts[index] = savedPost
        } else {
            posts.insert(savedPost, at: 0)
        }
    }

    private func loadPosts() async {
        do {
            posts = try await BlogAPIService.getMyPosts()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func deletePost(_ post: BlogPost) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let removed = posts.remove(at: index)

        do {
            try await BlogAPIService.deletePost(id: post.id)
        } catch {
            posts.insert(removed, at: min(index, posts.count))
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
