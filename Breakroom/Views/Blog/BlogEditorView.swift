import SwiftUI
import WebKit
import PhotosUI

struct BlogEditorView: View {
    let existingPost: BlogPost?
    let onSave: (BlogPost) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var isPublished = false
    @State private var isSaving = false
    @State private var showSavedFeedback = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var editorCoordinator = RichTextEditorCoordinator()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var showLinkAlert = false
    @State private var linkURL = ""
    @State private var selectedFont = "Arial"
    @State private var selectedSize = "Normal"

    private let availableFonts = ["Arial", "Georgia", "Times", "Courier", "Verdana"]
    private let availableSizes = ["Small", "Normal", "Large", "X-Large"]

    init(existingPost: BlogPost?, onSave: @escaping (BlogPost) -> Void) {
        self.existingPost = existingPost
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Post Title", text: $title)
                .font(.title2.bold())
                .padding(.horizontal)
                .padding(.vertical, 10)

            Divider()

            formattingToolbar

            Divider()

            RichTextEditorView(
                initialHTML: existingPost?.content ?? "",
                coordinator: editorCoordinator
            )

            Divider()

            bottomBar
        }
        .navigationTitle(existingPost != nil ? "Edit Post" : "New Post")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .alert("Add Link", isPresented: $showLinkAlert) {
            TextField("https://example.com", text: $linkURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                if !linkURL.isEmpty {
                    editorCoordinator.insertLink(url: linkURL)
                }
            }
        } message: {
            Text("Enter the URL for the link")
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await uploadPhoto(item) }
            selectedPhoto = nil
        }
        .onAppear {
            if let post = existingPost {
                title = post.title
                isPublished = (post.isPublished ?? 0) != 0
            }
        }
    }

    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Font picker
                Menu {
                    ForEach(availableFonts, id: \.self) { font in
                        Button {
                            selectedFont = font
                            editorCoordinator.setFont(font)
                        } label: {
                            HStack {
                                Text(font)
                                if selectedFont == font {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedFont)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .frame(minWidth: 70)
                }
                .accessibilityLabel("Font: \(selectedFont)")
                .accessibilityHint("Double tap to change font")

                // Size picker
                Menu {
                    ForEach(availableSizes, id: \.self) { size in
                        Button {
                            selectedSize = size
                            editorCoordinator.setFontSize(size)
                        } label: {
                            HStack {
                                Text(size)
                                if selectedSize == size {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedSize)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
                .accessibilityLabel("Size: \(selectedSize)")
                .accessibilityHint("Double tap to change text size")

                Divider()
                    .frame(height: 20)
                    .accessibilityHidden(true)

                // Text formatting
                Button { editorCoordinator.execCommand("bold") } label: {
                    Text("B").bold()
                }
                .accessibilityLabel("Bold")

                Button { editorCoordinator.execCommand("italic") } label: {
                    Text("I").italic()
                }
                .accessibilityLabel("Italic")

                Button { editorCoordinator.execCommand("underline") } label: {
                    Text("U").underline()
                }
                .accessibilityLabel("Underline")

                Divider()
                    .frame(height: 20)
                    .accessibilityHidden(true)

                // Link button
                Button {
                    linkURL = ""
                    showLinkAlert = true
                } label: {
                    Image(systemName: "link")
                }
                .accessibilityLabel("Insert link")

                // Image picker
                if isUploadingImage {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Uploading image")
                } else {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Image(systemName: "photo")
                    }
                    .accessibilityLabel("Insert image from photo library")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var bottomBar: some View {
        HStack {
            Toggle("Published", isOn: $isPublished)
                .fixedSize()
                .accessibilityHint(isPublished ? "Post will be visible to others" : "Post will be saved as draft")
            Spacer()
            Button {
                Task { await save() }
            } label: {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(showSavedFeedback ? "Saved!" : "Save")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(showSavedFeedback ? .green : nil)
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            .accessibilityLabel(isSaving ? "Saving post" : (showSavedFeedback ? "Post saved" : "Save post"))
        }
        .padding()
    }

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        isUploadingImage = true
        AccessibilityNotification.Announcement("Uploading image").post()
        defer { isUploadingImage = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let filename = "image_\(Int(Date().timeIntervalSince1970)).jpg"
            let url = try await BlogAPIService.uploadImage(imageData: data, filename: filename)
            editorCoordinator.insertImage(url: url)
            AccessibilityNotification.Announcement("Image inserted").post()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            AccessibilityNotification.Announcement("Failed to upload image").post()
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let html: String
        do {
            guard let result = try await editorCoordinator.getHTML() else {
                errorMessage = "Could not read editor content"
                showError = true
                return
            }
            html = result
        } catch {
            errorMessage = "Could not read editor content: \(error.localizedDescription)"
            showError = true
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        do {
            let savedPost: BlogPost
            if let existing = existingPost {
                savedPost = try await BlogAPIService.updatePost(
                    id: existing.id,
                    title: trimmedTitle,
                    content: html,
                    isPublished: isPublished
                )
            } else {
                savedPost = try await BlogAPIService.createPost(
                    title: trimmedTitle,
                    content: html,
                    isPublished: isPublished
                )
            }
            onSave(savedPost)
            AccessibilityNotification.Announcement("Post saved successfully").post()
            if isPublished {
                dismiss()
            } else {
                showSavedFeedback = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showSavedFeedback = false
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            AccessibilityNotification.Announcement("Failed to save post").post()
        }
    }
}

// MARK: - Rich Text Editor (WKWebView)

struct RichTextEditorView: UIViewRepresentable {
    let initialHTML: String
    let coordinator: RichTextEditorCoordinator

    func makeCoordinator() -> RichTextEditorCoordinator {
        coordinator
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        context.coordinator.webView = webView

        let html = editorHTML(content: initialHTML)
        webView.loadHTMLString(html, baseURL: URL(string: APIClient.shared.baseURL))

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates — coordinator manages content via JS
    }

    private func editorHTML(content: String) -> String {
        let escapedContent = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body {
                font-family: -apple-system, system-ui;
                font-size: 16px;
                line-height: 1.6;
                padding: 16px;
                min-height: 100vh;
                -webkit-text-size-adjust: 100%;
            }
            @media (prefers-color-scheme: dark) {
                body { color: #fff; background: transparent; }
                a { color: #58a6ff; }
            }
            @media (prefers-color-scheme: light) {
                body { color: #000; background: transparent; }
            }
            #editor {
                outline: none;
                min-height: 200px;
            }
            #editor:empty:before {
                content: 'Start writing...';
                color: #999;
                pointer-events: none;
            }
            #editor img {
                max-width: 100%;
                height: auto;
                border-radius: 8px;
                margin: 8px 0;
            }
            blockquote {
                border-left: 3px solid #ccc;
                margin: 8px 0;
                padding-left: 12px;
                color: #666;
            }
            pre {
                background: #f5f5f5;
                padding: 12px;
                border-radius: 6px;
                overflow-x: auto;
                font-size: 14px;
            }
            @media (prefers-color-scheme: dark) {
                pre { background: #1e1e1e; }
                blockquote { border-color: #555; color: #aaa; }
            }
        </style>
        </head>
        <body>
        <div id="editor" contenteditable="true">\(escapedContent)</div>
        <script>
            // Handle Enter key to insert line breaks
            document.getElementById('editor').addEventListener('keydown', function(e) {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    document.execCommand('insertLineBreak');
                }
            });
        </script>
        </body>
        </html>
        """
    }
}

@MainActor
class RichTextEditorCoordinator: NSObject, WKNavigationDelegate {
    var webView: WKWebView?
    private var hasLoaded = false

    nonisolated override init() {
        super.init()
    }

    func execCommand(_ command: String) {
        webView?.evaluateJavaScript("document.execCommand('\(command)', false, null)")
    }

    func setFont(_ font: String) {
        let fontFamily: String
        switch font {
        case "Georgia":
            fontFamily = "Georgia, serif"
        case "Times":
            fontFamily = "Times New Roman, Times, serif"
        case "Courier":
            fontFamily = "Courier New, Courier, monospace"
        case "Verdana":
            fontFamily = "Verdana, Geneva, sans-serif"
        default: // Arial
            fontFamily = "Arial, Helvetica, sans-serif"
        }
        webView?.evaluateJavaScript("document.execCommand('fontName', false, '\(fontFamily)')")
    }

    func setFontSize(_ size: String) {
        // HTML font sizes are 1-7
        let htmlSize: String
        switch size {
        case "Small": htmlSize = "2"
        case "Large": htmlSize = "5"
        case "X-Large": htmlSize = "6"
        default: htmlSize = "3" // Normal
        }
        webView?.evaluateJavaScript("document.execCommand('fontSize', false, '\(htmlSize)')")
    }

    func insertLink(url: String) {
        var finalURL = url
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            finalURL = "https://" + url
        }
        webView?.evaluateJavaScript("document.execCommand('createLink', false, '\(finalURL)')")
    }

    func insertImage(url: String) {
        let imgTag = "<img src=\\\"\(url)\\\" />"
        webView?.evaluateJavaScript("document.execCommand('insertHTML', false, '\(imgTag)')")
    }

    func getHTML() async throws -> String? {
        guard let webView else { return nil }
        let result = try await webView.evaluateJavaScript("document.getElementById('editor').innerHTML")
        return result as? String
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .other {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hasLoaded = true
    }
}
