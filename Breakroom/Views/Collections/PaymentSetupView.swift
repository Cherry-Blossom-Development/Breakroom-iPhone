import SwiftUI

struct PaymentSetupView: View {
    @State private var isLoading = true
    @State private var error: String?

    // Billing plan
    @State private var planSubscribed = false
    @State private var planFeePercent = 5
    @State private var planPlatform: String?

    // Connect status
    @State private var connectStatus = "not_connected" // "not_connected", "pending", "active"
    @State private var isStartingConnect = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading payment info...")
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Plan card
                        planCard

                        if let error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }

                        // Payout Account section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Payout Account")
                                .font(.headline)
                                .padding(.horizontal)

                            switch connectStatus {
                            case "active":
                                activeConnectCard
                            case "pending":
                                pendingConnectCard
                            default:
                                notConnectedCard
                            }
                        }

                        // How it works
                        howItWorksSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Payment Setup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPaymentInfo()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await loadPaymentInfo() }
            }
        }
    }

    // MARK: - Plan Card

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(planSubscribed ? "Prosaurus Pro" : "Free Plan")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(planSubscribed ? .purple : .secondary)

            Text(planSubscribed ? "0% application fee on all artwork sales" : "5% application fee applied to each sale")
                .font(.subheadline)
                .fontWeight(.bold)

            Text(planNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(planSubscribed ? Color.purple.opacity(0.1) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var planNote: String {
        if planSubscribed {
            switch planPlatform {
            case "google": return "Subscribed via Android — manage in Google Play"
            case "apple": return "Subscribed via iOS — manage in the App Store"
            case "promo": return "Complimentary Pro account"
            default: return "Pro plan active"
            }
        }
        return "Upgrade to Pro to keep 100% of your sale price (minus Stripe's processing fee)"
    }

    // MARK: - Connect Cards

    private var notConnectedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "creditcard")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("No payout account connected")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Connect a Stripe account to receive payouts from your sales.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task { await startConnect() }
            } label: {
                HStack {
                    if isStartingConnect {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isStartingConnect ? "Redirecting…" : "Connect with Stripe")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isStartingConnect)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private var pendingConnectCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Setup incomplete")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Your Stripe account was created but onboarding isn't finished yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task { await startConnect() }
            } label: {
                HStack {
                    if isStartingConnect {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isStartingConnect ? "Redirecting…" : "Continue Stripe Setup")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isStartingConnect)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var activeConnectCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Stripe account connected")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Your account is ready to accept payments. Payouts go directly to your bank.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                if let url = URL(string: "https://dashboard.stripe.com/express") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Stripe Dashboard ↗")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - How It Works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            Text("How it works")
                .font(.headline)

            howItWorksStep(
                number: "1",
                title: "Connect your Stripe payout account",
                description: "Create or link a Stripe account. Stripe collects your bank info for payouts."
            )

            howItWorksStep(
                number: "2",
                title: "Set prices on your products",
                description: "Add pricing to items in your collections. Each piece can have its own price and shipping cost."
            )

            howItWorksStep(
                number: "3",
                title: "Customers buy from your store",
                description: "Stripe processes payments securely. Pro members keep 100% of their sale price (minus Stripe's ~2.9% + $0.30 fee). Free members also have a 5% platform fee deducted."
            )
        }
    }

    private func howItWorksStep(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 28, height: 28)
                .overlay {
                    Text(number)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func loadPaymentInfo() async {
        isLoading = true
        error = nil

        do {
            async let planResult = CollectionsAPIService.getBillingPlan()
            async let statusResult = CollectionsAPIService.getConnectStatus()

            let plan = try await planResult
            let status = try await statusResult

            planSubscribed = plan.subscribed
            planFeePercent = plan.feePercent
            planPlatform = plan.platform
            connectStatus = status.status
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func startConnect() async {
        isStartingConnect = true
        error = nil

        do {
            let response = try await CollectionsAPIService.startConnect()

            if response.status == "active" {
                connectStatus = "active"
            } else if let url = response.url, let openUrl = URL(string: url) {
                await MainActor.run {
                    UIApplication.shared.open(openUrl)
                }
            } else {
                error = "Unexpected response from server"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isStartingConnect = false
    }
}
