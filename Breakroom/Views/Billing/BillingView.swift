import SwiftUI

struct BillingView: View {
    @State private var isLoading = true
    @State private var planSubscribed = false
    @State private var planFeePercent = 5
    @State private var planPlatform: String?
    @State private var isOpeningPortal = false
    @State private var error: String?

    private var storeKit = StoreKitManager.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading billing info...")
            } else {
                billingContent
            }
        }
        .navigationTitle("Billing & Plans")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBillingPlan()
            await storeKit.loadProduct()
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            if let error {
                Text(error)
            }
        }
    }

    private var billingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Intro text
                Text("Prosaurus offers two tiers. Most features are completely free — Pro is only needed if you want to sell artwork without a platform fee, or need extra session storage.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Current plan banner
                currentPlanBanner

                // Error message
                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // Free tier card
                freeTierCard

                // Pro tier card
                proTierCard

                // Fee breakdown
                feeBreakdownCard

                Spacer(minLength: 24)
            }
            .padding()
        }
    }

    // MARK: - Current Plan Banner

    private var currentPlanBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR CURRENT PLAN")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .kerning(0.8)
                Text(planSubscribed ? "Pro" : "Free")
                    .font(.title2.bold())
                    .foregroundStyle(planSubscribed ? .purple : .primary)
            }
            Spacer()
            Text(planSubscribed ? "0% platform fee\non sales" : "5% platform fee\non sales")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding()
        .background(planSubscribed ? Color.purple.opacity(0.15) : Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current plan: \(planSubscribed ? "Pro" : "Free"). \(planSubscribed ? "0 percent" : "5 percent") platform fee on sales")
    }

    // MARK: - Free Tier Card

    private var freeTierCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("FREE")
                        .font(.caption.bold())
                        .kerning(0.5)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())

                    if !planSubscribed {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("$0 / month")
                    .font(.subheadline.bold())
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                featureRow(included: true, text: "Chat & messaging")
                featureRow(included: true, text: "Breakroom dashboard")
                featureRow(included: true, text: "Blog")
                featureRow(included: true, text: "Collections & storefront")
                featureRow(included: true, text: "Gallery")
                featureRow(included: true, text: "Friends & social")
                featureRow(included: true, text: "Company profiles")
                featureRow(included: true, text: "Bands & instruments")
                featureRow(included: true, text: "Projects & Lyrics")
                featureRow(included: true, text: "Sessions (standard storage)")
                featureRow(included: true, text: "Help desk access")
                featureRow(included: false, text: "5% Prosaurus fee on art sales")
            }
        }
        .padding()
        .background(!planSubscribed ? Color(.secondarySystemBackground) : Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Pro Tier Card

    private var proTierCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("PRO")
                        .font(.caption.bold())
                        .kerning(0.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.purple)
                        .clipShape(Capsule())

                    if planSubscribed {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                }
                Spacer()
                if !planSubscribed {
                    Text("$3.99 / month")
                        .font(.subheadline.bold())
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                featureRow(included: true, text: "Everything in Free")

                Divider()

                featureRow(included: true, text: "No Prosaurus platform fee on art sales", isPro: true)
                featureRow(included: true, text: "Extra storage on Sessions", isPro: true)
            }

            // StoreKit error
            if let errorMessage = storeKit.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Action button
            if planSubscribed {
                if planPlatform != nil {
                    Button {
                        Task { await openSubscriptionManagement() }
                    } label: {
                        HStack {
                            Spacer()
                            if isOpeningPortal {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Opening...")
                            } else {
                                Text("Manage Subscription")
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isOpeningPortal)
                }
            } else {
                Button {
                    Task { await purchaseSubscription() }
                } label: {
                    HStack {
                        Spacer()
                        if storeKit.isPurchasing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                            Text("Processing...")
                                .foregroundStyle(.white)
                        } else {
                            Text("Upgrade to Pro — $3.99/mo")
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(storeKit.isPurchasing)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Fee Breakdown Card

    private var feeBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How art sale fees work")
                .font(.headline)

            Text("When a buyer purchases artwork through your storefront, payment is processed by Stripe. Stripe always charges their standard processing fee — this is not a Prosaurus fee and cannot be waived.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                feeExampleCard(
                    label: "Free — $10 sale",
                    rows: [
                        ("Stripe", "−$0.59", false),
                        ("Platform fee", "−$0.50", false)
                    ],
                    total: "$8.91",
                    isPro: false
                )

                feeExampleCard(
                    label: "Pro — $10 sale",
                    rows: [
                        ("Stripe", "−$0.59", false),
                        ("Platform fee", "waived", true)
                    ],
                    total: "$9.41",
                    isPro: true
                )
            }

            Text("At roughly 8 sales per month averaging $10, Pro pays for itself. At higher volume or higher prices, the savings are significantly larger.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helper Views

    private func featureRow(included: Bool, text: String, isPro: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(included ? "✓" : "✗")
                .font(.subheadline.bold())
                .foregroundStyle(
                    !included ? .red :
                    isPro ? .purple :
                    .green
                )
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fontWeight(isPro ? .semibold : .regular)
        }
    }

    private func feeExampleCard(label: String, rows: [(String, String, Bool)], total: String, isPro: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            Divider()

            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.1)
                        .font(.caption2)
                        .foregroundStyle(row.2 ? .green : .secondary)
                        .italic(row.2)
                }
            }

            Divider()

            HStack {
                Text("You receive")
                    .font(.caption2.bold())
                Spacer()
                Text(total)
                    .font(.caption2.bold())
            }
        }
        .padding(10)
        .background(isPro ? Color.purple.opacity(0.15) : Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private func loadBillingPlan() async {
        isLoading = true
        do {
            let plan = try await CollectionsAPIService.getBillingPlan()
            planSubscribed = plan.subscribed
            planFeePercent = plan.feePercent
            planPlatform = plan.platform
        } catch {
            self.error = "Failed to load billing info"
        }
        isLoading = false
    }

    private func purchaseSubscription() async {
        let success = await storeKit.purchase()
        if success {
            // Reload billing plan to reflect new subscription
            await loadBillingPlan()
        }
    }

    private func openSubscriptionManagement() async {
        isOpeningPortal = true

        switch planPlatform {
        case "stripe":
            // Open Stripe billing portal
            do {
                let url = try await CollectionsAPIService.getBillingPortalUrl()
                if let portalURL = URL(string: url) {
                    await MainActor.run {
                        UIApplication.shared.open(portalURL)
                    }
                }
            } catch {
                self.error = "Failed to open billing portal"
            }

        case "apple":
            // Open iOS subscription settings
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }

        default:
            break
        }

        isOpeningPortal = false
    }
}
