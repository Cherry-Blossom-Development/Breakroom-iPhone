import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text("Privacy Policy")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Prosaurus - Mobile Application")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Effective Date: February 20, 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                Text("This Privacy Policy describes how Cherry Blossom Development LLC (\"we,\" \"us,\" or \"our\"), based in Spokane, Washington, collects, uses, and protects your information when you use the Prosaurus mobile application (the \"App\"). By using the App, you agree to the practices described in this policy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                PrivacySectionView(
                    number: "1",
                    title: "Age Requirement",
                    content: "The Prosaurus App is intended for use by adults only. You must be at least 18 years of age to create an account or use this App. We do not knowingly collect personal information from anyone under the age of 18. If we become aware that a user under 18 has provided us with personal information, we will promptly delete that account and its associated data."
                )

                PrivacySectionView(
                    number: "2",
                    title: "Information We Collect",
                    content: """
                    We collect information you provide directly, as well as certain information automatically.

                    Information You Provide:
                    • Account Information: Username, email address, and password when you register.
                    • Profile Information: Display name, profile photo, bio, and any other details you choose to add.
                    • User Content: Posts, blog entries, artwork, comments, messages, and other content you create or share.
                    • Payment Information: Billing details processed through our payment provider. We do not store full payment card numbers on our servers.
                    • Communications: Any information you send us via email or support requests.

                    Information Collected Automatically:
                    • Device Information: Device type, operating system version, and unique device identifiers.
                    • Usage Data: Features accessed, content viewed, and interactions within the App.
                    • Log Data: IP address, access times, and error reports.
                    • Authentication Tokens: Session tokens stored securely to keep you logged in.
                    """
                )

                PrivacySectionView(
                    number: "3",
                    title: "How We Use Your Information",
                    content: """
                    We use the information we collect to:
                    • Provide, operate, and improve the App and its features.
                    • Authenticate your identity and maintain the security of your account.
                    • Process subscription payments and manage your billing.
                    • Send you service-related notifications.
                    • Respond to your support requests and communications.
                    • Monitor and enforce our Terms of Service, including age restrictions.
                    • Detect and prevent fraud, abuse, or other harmful activity.
                    • Analyze usage trends to improve the user experience.

                    We do not sell your personal information to third parties. We do not use your data for behavioral advertising or share it with advertisers.
                    """
                )

                PrivacySectionView(
                    number: "4",
                    title: "How We Share Your Information",
                    content: """
                    We may share your information only in the following limited circumstances:

                    • With Other Users: Content you post publicly is visible to others as you intend. Your username and profile are visible to other registered users within the App.
                    • Service Providers: We work with trusted third-party vendors who assist us in operating the App. These providers are contractually obligated to protect your information.
                    • Legal Requirements: We may disclose your information if required to do so by law or court order.
                    • Business Transfers: In the event of a merger or acquisition, your information may be transferred as part of that transaction.
                    """
                )

                PrivacySectionView(
                    number: "5",
                    title: "Data Retention",
                    content: "We retain your personal information for as long as your account is active or as needed to provide you with services. If you delete your account, we will delete or anonymize your personal data within a reasonable period, except where we are required to retain it for legal or legitimate business purposes."
                )

                PrivacySectionView(
                    number: "6",
                    title: "Data Security",
                    content: "We take reasonable technical and organizational measures to protect your information from unauthorized access, loss, or misuse. These measures include encrypted connections (HTTPS/TLS), secure password hashing, and access controls on our servers.\n\nYou are responsible for keeping your password confidential. Do not share your login credentials with anyone."
                )

                PrivacySectionView(
                    number: "7",
                    title: "Your Rights and Choices",
                    content: """
                    You have the following rights regarding your personal information:
                    • Access: You may request a copy of the personal information we hold about you.
                    • Correction: You may update or correct inaccurate information through your account settings.
                    • Deletion: You may request that we delete your account and associated personal data.
                    • Portability: You may request an export of your data in a commonly used format.
                    • Opt-Out of Notifications: You can manage notification preferences within the App settings.

                    To exercise any of these rights, please contact us at the address listed in Section 10.
                    """
                )

                PrivacySectionView(
                    number: "8",
                    title: "Third-Party Links and Services",
                    content: "The App may contain links to external websites or services not operated by us. We are not responsible for the privacy practices of those third parties. We encourage you to review the privacy policies of any external services you access."
                )

                PrivacySectionView(
                    number: "9",
                    title: "Changes to This Policy",
                    content: "We may update this Privacy Policy from time to time. When we make material changes, we will update the effective date at the top of this page and, where appropriate, notify you through the App or via email. Your continued use of the App after any changes constitutes your acceptance of the updated policy."
                )

                PrivacySectionView(
                    number: "10",
                    title: "Contact Us",
                    content: "If you have questions, concerns, or requests regarding this Privacy Policy or your personal data, please contact us:\n\nCherry Blossom Development LLC\nSpokane, Washington\nUnited States\nprivacy@cherryblossomdevelopment.com"
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Section View

private struct PrivacySectionView: View {
    let number: String
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(title)")
                .font(.headline)
                .foregroundStyle(.primary)

            Divider()

            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
