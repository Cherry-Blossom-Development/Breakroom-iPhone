import SwiftUI

/// A Text view that automatically detects URLs and makes them tappable links.
/// URLs are rendered with underline styling and open in the default browser when tapped.
struct LinkifiedText: View {
    let text: String
    let linkColor: Color
    let textColor: Color

    init(_ text: String, linkColor: Color = .accentColor, textColor: Color = .primary) {
        self.text = text
        self.linkColor = linkColor
        self.textColor = textColor
    }

    var body: some View {
        Text(attributedString)
    }

    private var attributedString: AttributedString {
        var result = AttributedString(text)

        // Find all URLs in the text
        let urlMatches = Self.findURLs(in: text)

        for match in urlMatches {
            // Convert NSRange to Swift Range<String.Index>
            guard let swiftRange = Range(match.range, in: text) else { continue }

            // Get the range in the AttributedString
            guard let lowerBound = AttributedString.Index(swiftRange.lowerBound, within: result),
                  let upperBound = AttributedString.Index(swiftRange.upperBound, within: result) else {
                continue
            }

            // Strip trailing punctuation that's likely sentence punctuation
            let matchedText = String(text[swiftRange])
            let (urlString, _) = Self.splitTrailingPunctuation(matchedText)

            // Build the full URL (add https:// if it starts with www.)
            let href = urlString.lowercased().hasPrefix("www.")
                ? "https://\(urlString)"
                : urlString

            guard let url = URL(string: href) else { continue }

            // Calculate the actual URL range (without trailing punctuation)
            let urlEndIndex = text.index(swiftRange.lowerBound, offsetBy: urlString.count)
            guard let urlLowerBound = AttributedString.Index(swiftRange.lowerBound, within: result),
                  let urlUpperBound = AttributedString.Index(urlEndIndex, within: result) else {
                continue
            }

            let urlRange = urlLowerBound..<urlUpperBound

            // Apply link styling
            result[urlRange].link = url
            result[urlRange].foregroundColor = linkColor
            result[urlRange].underlineStyle = .single
        }

        // Apply default text color to non-link text
        for run in result.runs {
            if result[run.range].link == nil {
                result[run.range].foregroundColor = textColor
            }
        }

        return result
    }

    // MARK: - URL Detection

    /// Regex pattern for matching URLs (http://, https://, or www.)
    private static let urlPattern = try! NSRegularExpression(
        pattern: #"\b(?:https?://|www\.)[^\s<>"']+\b"#,
        options: [.caseInsensitive]
    )

    /// Find all URL matches in the text
    private static func findURLs(in text: String) -> [NSTextCheckingResult] {
        let range = NSRange(text.startIndex..., in: text)
        return urlPattern.matches(in: text, options: [], range: range)
    }

    /// Strips trailing punctuation that's more likely to be sentence punctuation than part of the URL.
    /// Keeps closing parens/brackets that balance ones inside the URL.
    private static func splitTrailingPunctuation(_ url: String) -> (url: String, trailing: String) {
        let trailingPattern = try! NSRegularExpression(pattern: #"[.,!?:;)\]}'"]+$"#)
        let range = NSRange(url.startIndex..., in: url)

        guard let match = trailingPattern.firstMatch(in: url, options: [], range: range) else {
            return (url, "")
        }

        var trailingRange = Range(match.range, in: url)!
        var trailing = String(url[trailingRange])
        var core = String(url[..<trailingRange.lowerBound])

        // Keep closing parens that balance opening parens in the URL
        while trailing.hasPrefix(")") {
            let openCount = core.filter { $0 == "(" }.count
            let closeCount = core.filter { $0 == ")" }.count
            if openCount > closeCount {
                core += String(trailing.removeFirst())
            } else {
                break
            }
        }

        return (core, trailing)
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        LinkifiedText("Check out https://www.example.com for more info!")

        LinkifiedText("Visit www.google.com or https://apple.com today.")

        LinkifiedText("No links here, just plain text.")

        LinkifiedText(
            "Link in dark mode: https://prosaurus.com",
            linkColor: .white.opacity(0.9),
            textColor: .white
        )
        .padding()
        .background(Color.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}
