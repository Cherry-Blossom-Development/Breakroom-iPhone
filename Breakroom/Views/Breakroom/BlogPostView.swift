import SwiftUI
import WebKit

struct BlogPostView: View {
    let post: BlogPost

    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var fullPost: BlogPost?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    private var displayPost: BlogPost {
        fullPost ?? post
    }

    private var isOwnPost: Bool {
        guard let currentUserId = authViewModel.currentUserId else { return false }
        return displayPost.authorId == currentUserId
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                authorHeader
                titleSection
                if let content = displayPost.content {
                    HTMLContentView(html: content)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnPost {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        NavigationLink {
                            BlogEditorView(existingPost: displayPost) { savedPost in
                                fullPost = savedPost
                            }
                        } label: {
                            Image(systemName: "pencil")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(isDeleting)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Post",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                Task { await deletePost() }
            }
        } message: {
            Text("Are you sure you want to delete \"\(displayPost.title)\"?")
        }
        .task {
            await loadFullPost()
        }
    }

    // MARK: - Author Header

    private var authorHeader: some View {
        HStack(spacing: 10) {
            if let photoPath = displayPost.authorPhoto, !photoPath.isEmpty {
                AuthenticatedImage(
                    path: photoPath,
                    maxWidth: 40,
                    maxHeight: 40,
                    cornerRadius: 20
                )
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(displayPost.authorDisplayName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.green)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayPost.authorDisplayName)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 4) {
                    if let handle = displayPost.authorHandle {
                        Text("@\(handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !displayPost.formattedDate.isEmpty {
                        if displayPost.authorHandle != nil {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(displayPost.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        Text(displayPost.title)
            .font(.title2.weight(.bold))
    }

    // MARK: - Data

    private func loadFullPost() async {
        do {
            fullPost = try await BlogAPIService.viewPost(id: post.id)
        } catch {
            // Keep using the feed data passed in
        }
    }

    private func deletePost() async {
        isDeleting = true
        do {
            try await BlogAPIService.deletePost(id: post.id)
            dismiss()
        } catch {
            // Stay on page if delete fails
            isDeleting = false
        }
    }
}

// MARK: - HTMLContentView

struct HTMLContentView: UIViewRepresentable {
    let html: String

    @State private var contentHeight: CGFloat = 300

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        let textColor = isDark ? "#F5F5F7" : "#1D1D1F"
        let codeBg = isDark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.05)"
        let secondaryText = isDark ? "#98989D" : "#86868B"
        let accentColor = "#34C759"
        let borderColor = isDark ? "rgba(255,255,255,0.15)" : "rgba(0,0,0,0.12)"

        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
            * { box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: 17px;
                line-height: 1.6;
                color: \(textColor);
                background-color: transparent;
                margin: 0;
                padding: 0;
                word-wrap: break-word;
                -webkit-text-size-adjust: 100%;
            }
            img {
                max-width: 100%;
                height: auto;
                border-radius: 8px;
                margin: 8px 0;
            }
            pre {
                background-color: \(codeBg);
                padding: 12px;
                border-radius: 8px;
                overflow-x: auto;
                font-size: 14px;
                line-height: 1.4;
            }
            code {
                font-family: ui-monospace, Menlo, monospace;
                font-size: 0.9em;
            }
            p code {
                background-color: \(codeBg);
                padding: 2px 6px;
                border-radius: 4px;
            }
            blockquote {
                border-left: 3px solid \(accentColor);
                margin: 12px 0;
                padding: 4px 12px;
                color: \(secondaryText);
            }
            a { color: \(accentColor); }
            h1, h2, h3, h4, h5, h6 {
                line-height: 1.3;
                margin-top: 20px;
                margin-bottom: 8px;
            }
            p { margin: 8px 0; }
            ul, ol { padding-left: 24px; }
            table {
                border-collapse: collapse;
                width: 100%;
                margin: 12px 0;
            }
            th, td {
                border: 1px solid \(borderColor);
                padding: 8px;
                text-align: left;
            }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """

        let baseURL = URL(string: APIClient.shared.baseURL)
        webView.loadHTMLString(styledHTML, baseURL: baseURL)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: WKWebView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 300, height: context.coordinator.contentHeight)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: HTMLContentView
        var contentHeight: CGFloat = 300

        init(parent: HTMLContentView) {
            self.parent = parent
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Allow initial HTML load
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
                return
            }

            // Open external links in Safari
            if url.scheme == "http" || url.scheme == "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectAuthAndResize(webView)
        }

        private func injectAuthAndResize(_ webView: WKWebView) {
            let token = KeychainManager.bearerToken ?? ""
            let baseURL = APIClient.shared.baseURL

            let js = """
            (function() {
                document.querySelectorAll('img').forEach(function(img) {
                    var src = img.getAttribute('src');
                    if (src && (src.startsWith('/api/') || src.startsWith('\(baseURL)/api/'))) {
                        var fullURL = src.startsWith('http') ? src : '\(baseURL)' + src;
                        fetch(fullURL, {
                            headers: { 'Authorization': '\(token)' }
                        })
                        .then(function(r) { return r.blob(); })
                        .then(function(blob) {
                            var url = URL.createObjectURL(blob);
                            img.src = url;
                        })
                        .catch(function() {});
                    }
                });
                return document.body.scrollHeight;
            })();
            """

            webView.evaluateJavaScript(js) { [weak self] result, _ in
                if let height = result as? CGFloat, height > 0 {
                    DispatchQueue.main.async {
                        self?.contentHeight = height
                        webView.invalidateIntrinsicContentSize()
                    }
                }
            }
        }
    }
}
