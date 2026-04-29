import Foundation
import StoreKit
import os

private let storeKitLogger = Logger(subsystem: "com.cherryblossomdev.Breakroom", category: "StoreKit")

@MainActor
@Observable
final class StoreKitManager {
    static let shared = StoreKitManager()

    // Product ID - must match App Store Connect
    static let premiumMonthlyProductId = "breakroom_premium_monthly"

    // State
    private(set) var product: Product?
    private(set) var isSubscribed = false
    private(set) var isPurchasing = false
    private(set) var errorMessage: String?

    private nonisolated(unsafe) var transactionListener: Task<Void, Error>?

    private init() {
        // Start listening for transactions
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public Methods

    /// Load the subscription product from App Store
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.premiumMonthlyProductId])
            product = products.first
            if product == nil {
                storeKitLogger.warning("Product not found: \(Self.premiumMonthlyProductId)")
            } else {
                storeKitLogger.info("Product loaded: \(self.product?.displayName ?? "unknown")")
            }
        } catch {
            storeKitLogger.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    /// Check subscription status from backend
    func checkSubscriptionStatus() async {
        do {
            let status = try await SubscriptionAPIService.getStatus()
            isSubscribed = status.subscribed
            storeKitLogger.info("Subscription status: \(status.subscribed)")
        } catch {
            storeKitLogger.error("Failed to check subscription: \(error.localizedDescription)")
        }
    }

    /// Check local entitlements (for quick UI updates)
    func checkLocalEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.premiumMonthlyProductId {
                    isSubscribed = true
                    return
                }
            }
        }
    }

    /// Purchase the subscription
    func purchase() async -> Bool {
        guard let product else {
            errorMessage = "Subscription unavailable. Please try again later."
            return false
        }

        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Verify with backend
                let success = await verifyWithBackend(transaction: transaction)

                if success {
                    await transaction.finish()
                    isSubscribed = true
                    isPurchasing = false
                    storeKitLogger.info("Purchase successful")
                    return true
                } else {
                    isPurchasing = false
                    errorMessage = "Purchase complete but activation failed. Please contact support."
                    return false
                }

            case .userCancelled:
                storeKitLogger.info("User cancelled purchase")
                isPurchasing = false
                return false

            case .pending:
                storeKitLogger.info("Purchase pending")
                isPurchasing = false
                errorMessage = "Purchase is pending approval."
                return false

            @unknown default:
                isPurchasing = false
                return false
            }
        } catch {
            storeKitLogger.error("Purchase failed: \(error.localizedDescription)")
            isPurchasing = false
            errorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Verify with backend
                    _ = await self.verifyWithBackend(transaction: transaction)

                    await transaction.finish()

                    await MainActor.run {
                        if transaction.productID == Self.premiumMonthlyProductId {
                            self.isSubscribed = true
                        }
                    }
                } catch {
                    storeKitLogger.error("Transaction verification failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func verifyWithBackend(transaction: Transaction) async -> Bool {
        do {
            _ = try await SubscriptionAPIService.verifyApplePurchase(
                originalTransactionId: String(transaction.originalID)
            )
            storeKitLogger.info("Backend verification successful")
            return true
        } catch {
            storeKitLogger.error("Backend verification failed: \(error.localizedDescription)")
            return false
        }
    }
}
