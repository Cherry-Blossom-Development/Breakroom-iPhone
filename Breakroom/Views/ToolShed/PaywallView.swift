import SwiftUI

struct PaywallView: View {
    let onDismiss: () -> Void
    let onSubscribed: () -> Void

    @State private var storeKitManager = StoreKitManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple)

                    Text("Upgrade to Premium")
                        .font(.title.bold())

                    Text("Unlock the full Breakroom experience")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Features list
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(text: "Unlimited band practice sessions")
                    FeatureRow(text: "Unlimited individual sessions")
                    FeatureRow(text: "Unlimited bands")
                    FeatureRow(text: "Priority support")
                }
                .padding(.horizontal, 24)

                Spacer()

                // Price and subscribe button
                VStack(spacing: 16) {
                    if let product = storeKitManager.product {
                        Text("\(product.displayPrice) / month")
                            .font(.title2.bold())
                            .foregroundStyle(.purple)
                    } else {
                        Text("$3.99 / month")
                            .font(.title2.bold())
                            .foregroundStyle(.purple)
                    }

                    Text("Auto-renews monthly. Cancel anytime.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let error = storeKitManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            let success = await storeKitManager.purchase()
                            if success {
                                onSubscribed()
                            }
                        }
                    } label: {
                        HStack {
                            if storeKitManager.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                                Text("Processing...")
                            } else {
                                Text("Subscribe")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(storeKitManager.isPurchasing || storeKitManager.product == nil)
                    .padding(.horizontal, 24)

                    Button("Not now") {
                        onDismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .disabled(storeKitManager.isPurchasing)

                    // Legal links required by App Store
                    HStack(spacing: 16) {
                        NavigationLink {
                            TermsOfUseView()
                        } label: {
                            Text("Terms of Use")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            Text("Privacy Policy")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .disabled(storeKitManager.isPurchasing)
                }
            }
            .task {
                await storeKitManager.loadProduct()
            }
            .interactiveDismissDisabled(storeKitManager.isPurchasing)
        }
    }
}

private struct FeatureRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.purple)
                .font(.title3)

            Text(text)
                .font(.body)

            Spacer()
        }
    }
}

#Preview {
    PaywallView(onDismiss: {}, onSubscribed: {})
}
