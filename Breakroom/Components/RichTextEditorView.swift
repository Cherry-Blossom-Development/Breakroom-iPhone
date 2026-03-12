import SwiftUI
import WebKit

/// A reusable rich text editor component using WKWebView with contenteditable HTML.
/// Supports bold, italic, underline, strikethrough, and lists.
struct RichTextEditor: View {
    @Binding var html: String
    var placeholder: String = "Start writing..."
    var minHeight: CGFloat = 150
    var showToolbar: Bool = true

    @State private var coordinator = FormRichTextCoordinator()
    @State private var isLoaded = false

    var body: some View {
        VStack(spacing: 0) {
            if showToolbar {
                formattingToolbar
                Divider()
            }

            RichTextWebView(
                initialHTML: html,
                placeholder: placeholder,
                minHeight: minHeight,
                coordinator: coordinator,
                onLoad: { isLoaded = true }
            )
            .frame(minHeight: minHeight)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
        )
        .onChange(of: html) { _, newValue in
            // Only update if external change (not from editor)
            if isLoaded {
                coordinator.setContent(newValue)
            }
        }
        .onDisappear {
            // Save content when view disappears
            Task {
                if let content = try? await coordinator.getHTML() {
                    html = content
                }
            }
        }
    }

    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FormatButton(label: "B", action: { coordinator.execCommand("bold") })
                    .fontWeight(.bold)
                FormatButton(label: "I", action: { coordinator.execCommand("italic") })
                    .italic()
                FormatButton(label: "U", action: { coordinator.execCommand("underline") })
                    .underline()
                FormatButton(label: "S", action: { coordinator.execCommand("strikeThrough") })
                    .strikethrough()

                Divider()
                    .frame(height: 20)

                FormatButton(label: "• List", action: { coordinator.execCommand("insertUnorderedList") })
                FormatButton(label: "1. List", action: { coordinator.execCommand("insertOrderedList") })
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .tertiarySystemBackground))
    }

    /// Call this to get the current HTML content
    func getHTML() async throws -> String {
        try await coordinator.getHTML() ?? ""
    }
}

// MARK: - Format Button

private struct FormatButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

// MARK: - WKWebView Wrapper

struct RichTextWebView: UIViewRepresentable {
    let initialHTML: String
    let placeholder: String
    let minHeight: CGFloat
    let coordinator: FormRichTextCoordinator
    var onLoad: (() -> Void)?

    func makeCoordinator() -> FormRichTextCoordinator {
        coordinator
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        #if os(iOS)
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        webView.scrollView.isScrollEnabled = true
        #endif

        context.coordinator.webView = webView
        context.coordinator.onLoad = onLoad

        let html = editorHTML(content: initialHTML, placeholder: placeholder, minHeight: minHeight)
        webView.loadHTMLString(html, baseURL: nil)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Content updates handled via coordinator
    }

    private func editorHTML(content: String, placeholder: String, minHeight: CGFloat) -> String {
        let escapedContent = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        let escapedPlaceholder = placeholder
            .replacingOccurrences(of: "'", with: "\\'")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            html, body {
                height: 100%;
                background: transparent;
            }
            body {
                font-family: -apple-system, system-ui;
                font-size: 16px;
                line-height: 1.6;
                -webkit-text-size-adjust: 100%;
            }
            @media (prefers-color-scheme: dark) {
                body { color: #fff; }
                a { color: #58a6ff; }
            }
            @media (prefers-color-scheme: light) {
                body { color: #000; }
            }
            #editor {
                outline: none;
                min-height: \(Int(minHeight - 20))px;
                padding: 12px;
            }
            #editor:empty:before {
                content: '\(escapedPlaceholder)';
                color: #999;
                pointer-events: none;
            }
            #editor p { margin: 0 0 0.75em; }
            #editor p:last-child { margin-bottom: 0; }
            #editor ul, #editor ol {
                padding-left: 1.5em;
                margin: 0.5em 0;
            }
            #editor li { margin: 0.25em 0; }
            #editor strong { font-weight: 700; }
            #editor em { font-style: italic; }
            #editor u { text-decoration: underline; }
            #editor s, #editor strike { text-decoration: line-through; }
        </style>
        </head>
        <body>
        <div id="editor" contenteditable="true">\(escapedContent)</div>
        <script>
            const editor = document.getElementById('editor');

            // Notify Swift when content changes
            editor.addEventListener('input', function() {
                window.webkit.messageHandlers.contentChanged?.postMessage(editor.innerHTML);
            });

            // Handle Enter key to insert proper line breaks
            editor.addEventListener('keydown', function(e) {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    document.execCommand('insertParagraph');
                }
            });

            // Focus on tap
            document.body.addEventListener('click', function() {
                editor.focus();
            });
        </script>
        </body>
        </html>
        """
    }
}

// MARK: - Coordinator

@MainActor
class FormRichTextCoordinator: NSObject, WKNavigationDelegate, ObservableObject {
    weak var webView: WKWebView?
    var onLoad: (() -> Void)?
    private var hasLoaded = false

    nonisolated override init() {
        super.init()
    }

    func execCommand(_ command: String) {
        webView?.evaluateJavaScript("document.execCommand('\(command)', false, null)")
    }

    func setContent(_ html: String) {
        let escaped = html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        webView?.evaluateJavaScript("document.getElementById('editor').innerHTML = '\(escaped)'")
    }

    func getHTML() async throws -> String? {
        guard let webView else { return nil }
        let result = try await webView.evaluateJavaScript("document.getElementById('editor').innerHTML")
        return result as? String
    }

    nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .other {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.hasLoaded = true
            self.onLoad?()
        }
    }
}

// MARK: - HTML Text View (for displaying simple rich text snippets)

/// A view that renders simple HTML content as attributed text (for snippets/descriptions)
struct HTMLTextView: View {
    let html: String
    var font: Font = .body
    var foregroundColor: Color = .secondary

    var body: some View {
        if let attributedString = html.htmlToAttributedString() {
            Text(attributedString)
        } else {
            // Fallback: strip HTML tags and show plain text
            Text(html.strippingHTML())
                .font(font)
                .foregroundStyle(foregroundColor)
        }
    }
}

