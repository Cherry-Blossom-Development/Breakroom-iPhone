import SwiftUI

/// Read-only Terms of Use view for display in PaywallView
/// This is a simplified version of EulaView without the acceptance flow
struct TermsOfUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text("Terms of Use")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Prosaurus - prosaurus.com")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Effective Date: March 18, 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                TermsSectionView(
                    number: "1",
                    title: "Acceptance and Eligibility",
                    text: "You must be at least 18 years of age to use the Service. By using the Service, you represent and warrant that you meet this requirement. We reserve the right to terminate any account found to belong to a minor.\n\nYour use of the Service is also subject to our Privacy Policy, which is incorporated into this Agreement by reference."
                )

                TermsSectionView(
                    number: "2",
                    title: "License Grant",
                    text: "Subject to your compliance with this Agreement, Cherry Blossom Development LLC grants you a limited, non-exclusive, non-transferable, revocable license to access and use the Service for your personal, non-commercial purposes. This license does not include the right to sublicense, sell, resell, transfer, assign, or otherwise exploit the Service or any of its content."
                )

                TermsSectionView(
                    number: "3",
                    title: "Subscriptions and Billing",
                    text: """
                    Breakroom Premium is offered as an auto-renewing subscription:

                    • Subscription automatically renews monthly unless cancelled at least 24 hours before the end of the current period.
                    • Payment will be charged to your Apple ID account at confirmation of purchase.
                    • Your account will be charged for renewal within 24 hours prior to the end of the current period.
                    • You can manage and cancel your subscriptions by going to your App Store account settings after purchase.
                    • Any unused portion of a free trial period will be forfeited when you purchase a subscription.
                    """
                )

                TermsSectionView(
                    number: "4",
                    title: "Prohibited Content",
                    text: """
                    We maintain a zero-tolerance policy for objectionable content. The following types of content are strictly prohibited:

                    • Sexually explicit or pornographic content
                    • Content that exploits or endangers minors
                    • Hate speech or discriminatory content
                    • Content promoting violence, self-harm, or illegal activity
                    • Harassment, threats, or intimidation
                    • Spam, misinformation, or malware
                    """
                )

                TermsSectionView(
                    number: "5",
                    title: "Content Ownership",
                    text: "You retain ownership of content you create and post on the Service. By posting content, you grant Cherry Blossom Development LLC a worldwide, royalty-free, non-exclusive license to host, store, transmit, display, and distribute that content solely for the purpose of operating and improving the Service."
                )

                TermsSectionView(
                    number: "6",
                    title: "Termination",
                    text: "Cherry Blossom Development LLC reserves the right to suspend or permanently terminate any account, at any time and without prior notice, for any violation of this Agreement or for any conduct we determine to be harmful."
                )

                TermsSectionView(
                    number: "7",
                    title: "Disclaimer of Warranties",
                    text: "The Service is provided \"as is\" and \"as available,\" without warranties of any kind, express or implied. We do not warrant that the Service will be uninterrupted, error-free, or free of harmful components."
                )

                TermsSectionView(
                    number: "8",
                    title: "Limitation of Liability",
                    text: "To the maximum extent permitted by applicable law, Cherry Blossom Development LLC and its officers, directors, employees, and agents shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of or related to your use of the Service."
                )

                TermsSectionView(
                    number: "9",
                    title: "Governing Law",
                    text: "This Agreement is governed by the laws of the State of Washington, United States. Any disputes shall be resolved exclusively in the state or federal courts located in Spokane County, Washington."
                )

                TermsSectionView(
                    number: "10",
                    title: "Contact Us",
                    text: "If you have questions about these Terms, please contact us:\n\nCherry Blossom Development LLC\nSpokane, Washington, United States\nlegal@cherryblossomdevelopment.com"
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Section View

private struct TermsSectionView: View {
    let number: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(title)")
                .font(.headline)
                .foregroundStyle(.primary)

            Divider()

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
