import SwiftUI
import os

private let logger = Logger(subsystem: "com.cherryblossomdev.Breakroom", category: "EulaView")

struct EulaView: View {
    let onAccepted: () -> Void

    @State private var isLoading = true
    @State private var isAccepted = false
    @State private var notificationId: Int?
    @State private var isAccepting = false
    @State private var errorMessage: String?
    @State private var showPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    eulaContent
                }
            }
            .navigationDestination(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
        }
        .task {
            await checkStatus()
        }
    }

    private var eulaContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(spacing: 4) {
                        Text("End User License Agreement")
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

                    // Section 1 with Privacy Policy link
                    EulaSectionView(number: "1", title: "Acceptance and Eligibility") {
                        Text("You must be at least 18 years of age to use the Service. By using the Service, you represent and warrant that you meet this requirement. We reserve the right to terminate any account found to belong to a minor.\n\nYour use of the Service is also subject to our ")
                        + Text("Privacy Policy")
                            .foregroundColor(.accentColor)
                        + Text(", which is incorporated into this Agreement by reference.")
                    }
                    .onTapGesture {
                        showPrivacyPolicy = true
                    }

                    EulaSectionView(
                        number: "2",
                        title: "License Grant",
                        body: "Subject to your compliance with this Agreement, Cherry Blossom Development LLC grants you a limited, non-exclusive, non-transferable, revocable license to access and use the Service for your personal, non-commercial purposes. This license does not include the right to sublicense, sell, resell, transfer, assign, or otherwise exploit the Service or any of its content."
                    )

                    EulaSectionView(
                        number: "3",
                        title: "Prohibited Content - Zero Tolerance Policy",
                        body: """
                        We maintain a zero-tolerance policy for objectionable content. The following types of content are strictly prohibited and will result in immediate account termination without warning or refund:

                        • Sexually explicit or pornographic content of any kind.

                        • Content that exploits, endangers, or sexualizes minors in any way. Such content will be reported to the NCMEC and relevant law enforcement.

                        • Hate speech or discriminatory content targeting individuals or groups based on race, ethnicity, religion, gender, sexual orientation, disability, national origin, or any other protected characteristic.

                        • Content that promotes, glorifies, or incites violence, self-harm, terrorism, or illegal activity.

                        • Harassment, threats, or intimidation directed at any person or group.

                        • Spam, misinformation, or deliberately false content intended to deceive or mislead other users.

                        • Content that violates any applicable law, including copyright, defamation, privacy, or consumer protection laws.

                        • Malware, phishing links, or any content designed to compromise the security of other users or systems.
                        """
                    )

                    EulaSectionView(
                        number: "4",
                        title: "Prohibited Conduct - Zero Tolerance for Abusive Users",
                        body: """
                        We maintain a zero-tolerance policy for abusive behavior. The following conduct is strictly prohibited and will result in immediate and permanent account termination:

                        • Harassment or bullying of other users, including repeated unwanted contact, public humiliation, or coordinated attacks.

                        • Threatening or intimidating any user, employee, or person associated with the Service.

                        • Impersonating another person, company, or entity in a misleading or harmful way.

                        • Unauthorized access or hacking - attempting to access accounts, systems, or data that are not your own.

                        • Circumventing or undermining security measures, including sharing login credentials or attempting to bypass account verification.

                        • Deliberately disrupting the Service, including denial-of-service attacks, flooding, or other technically abusive behavior.

                        • Creating multiple accounts to evade a ban or circumvent any restriction placed on your access.

                        • Collecting or scraping user data without authorization.

                        Users who engage in any of the above conduct will be permanently banned. We cooperate fully with law enforcement when conduct may constitute a criminal offense.
                        """
                    )

                    EulaSectionView(
                        number: "5",
                        title: "Content Ownership and Responsibility",
                        body: "You retain ownership of content you create and post on the Service. By posting content, you grant Cherry Blossom Development LLC a worldwide, royalty-free, non-exclusive license to host, store, transmit, display, and distribute that content solely for the purpose of operating and improving the Service.\n\nYou are solely responsible for all content you post. We do not endorse any user-submitted content and expressly disclaim all liability arising from it."
                    )

                    EulaSectionView(
                        number: "6",
                        title: "Reporting Violations",
                        body: """
                        If you encounter content or behavior that violates this Agreement, please report it immediately using the in-app reporting tools or by contacting us at:

                        abuse@cherryblossomdevelopment.com

                        When content is reported or detected by our automated systems, it is immediately hidden from all users pending review. Users never see reported content while awaiting moderation. Our team reviews flagged content to confirm removal and take action against repeat offenders, including permanent account termination.

                        Reports submitted in good faith will be treated confidentially. We do not tolerate retaliation against users who report violations.
                        """
                    )

                    EulaSectionView(
                        number: "7",
                        title: "Automated Content Moderation",
                        body: """
                        To help maintain a safe environment, the Service uses automated tools to review user-submitted content for violations of this Agreement. These tools include:

                        • Keyword filtering — content is scanned against a list of prohibited terms maintained by Cherry Blossom Development LLC.

                        • OpenAI Moderation API — content is submitted to OpenAI's moderation service, which analyzes text for hate speech, harassment, sexual content, violence, and related categories. This processing is performed by OpenAI, L.L.C., a third-party service provider, and is subject to OpenAI's Privacy Policy.

                        Content flagged by either system may be automatically hidden and queued for human review. Automated moderation is not perfect — false positives can occur. If you believe your content was incorrectly removed, you may contact us at abuse@cherryblossomdevelopment.com to request a review.

                        By using the Service, you consent to your user-submitted content being processed by these automated systems as described above.
                        """
                    )

                    EulaSectionView(
                        number: "8",
                        title: "Enforcement and Account Termination",
                        body: "Cherry Blossom Development LLC reserves the right to suspend or permanently terminate any account, at any time and without prior notice, for any violation of this Agreement or for any conduct we determine to be harmful.\n\nUpon termination: your license to use the Service is immediately revoked, access to your account and all associated content will be disabled, active subscription fees are non-refundable in cases of policy violation, and we may retain records of your account and activity as required by law or for abuse prevention."
                    )

                    EulaSectionView(
                        number: "9",
                        title: "Disclaimer of Warranties",
                        body: "The Service is provided \"as is\" and \"as available,\" without warranties of any kind, express or implied. We do not warrant that the Service will be uninterrupted, error-free, or free of harmful components."
                    )

                    EulaSectionView(
                        number: "10",
                        title: "Limitation of Liability",
                        body: "To the maximum extent permitted by applicable law, Cherry Blossom Development LLC and its officers, directors, employees, and agents shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of or related to your use of the Service."
                    )

                    EulaSectionView(
                        number: "11",
                        title: "Governing Law",
                        body: "This Agreement is governed by the laws of the State of Washington, United States. Any disputes shall be resolved exclusively in the state or federal courts located in Spokane County, Washington."
                    )

                    EulaSectionView(
                        number: "12",
                        title: "Changes to This Agreement",
                        body: "We may update this EULA at any time. Your continued use of the Service after any changes constitutes your acceptance of the updated Agreement."
                    )

                    EulaSectionView(
                        number: "13",
                        title: "Contact Us",
                        body: "If you have questions or concerns about this Agreement, please contact us:\n\nCherry Blossom Development LLC\nSpokane, Washington, United States\nlegal@cherryblossomdevelopment.com"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }

            // Accept footer
            VStack(spacing: 12) {
                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await acceptEula() }
                } label: {
                    if isAccepting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Accept These Terms")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAccepting || notificationId == nil)
                .accessibilityIdentifier("acceptEulaButton")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
    }

    private func checkStatus() async {
        logger.info("checkStatus() called")
        logger.info("APIClient baseURL: \(APIClient.shared.baseURL)")
        isLoading = true
        do {
            logger.info("Calling getEulaStatus()...")
            let status = try await AuthService.getEulaStatus()
            logger.info("Got status: accepted=\(status.accepted), notificationId=\(status.notificationId ?? -1)")
            isAccepted = status.accepted
            notificationId = status.notificationId

            if isAccepted {
                logger.info("EULA already accepted, calling onAccepted()")
                onAccepted()
            } else {
                logger.info("EULA not accepted, showing form")
            }
        } catch {
            logger.error("Error fetching status: \(error)")
            // If we can't fetch status, don't block the user
            onAccepted()
        }
        isLoading = false
        logger.info("checkStatus() completed, isLoading=\(isLoading)")
    }

    private func acceptEula() async {
        guard let notifId = notificationId else { return }

        isAccepting = true
        errorMessage = nil

        do {
            try await AuthService.acceptEula(notificationId: notifId)
            onAccepted()
        } catch {
            #if DEBUG
            errorMessage = "Error: \(error.localizedDescription)"
            #else
            errorMessage = "Failed to save acceptance. Please try again."
            #endif
        }

        isAccepting = false
    }
}

// MARK: - Section View

private struct EulaSectionView<Content: View>: View {
    let number: String
    let title: String
    let content: Content

    init(number: String, title: String, @ViewBuilder content: () -> Content) {
        self.number = number
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(number). \(title)")
                .font(.headline)
                .foregroundStyle(.primary)

            Divider()

            content
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

extension EulaSectionView where Content == Text {
    init(number: String, title: String, body: String) {
        self.number = number
        self.title = title
        self.content = Text(body)
    }
}
