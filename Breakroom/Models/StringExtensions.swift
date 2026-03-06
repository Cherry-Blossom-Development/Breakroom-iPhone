import Foundation

extension String {
    /// Strips HTML tags from string
    func strippingHTML() -> String {
        guard let data = self.data(using: .utf8) else { return self }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }

        // Fallback regex strip
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    /// Converts HTML string to AttributedString for SwiftUI
    func htmlToAttributedString() -> AttributedString? {
        guard let data = self.data(using: .utf8) else { return nil }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let nsAttributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }

        return try? AttributedString(nsAttributedString, including: \.foundation)
    }
}
