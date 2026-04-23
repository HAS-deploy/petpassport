import Foundation
import StoreKit

/// StoreKit 2 wrapper. Non-consumable IAP (Pro Lifetime). Entitlement is
/// persisted in UserDefaults for fast UI reads, but the source of truth is
/// `Transaction.currentEntitlements` checked on every launch + transaction.
@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isPro: Bool = PurchaseManager.cachedIsPro
    @Published private(set) var purchaseInFlight: Bool = false
    @Published var lastError: String?

    private static let proKey = "petpassport.isPro"
    private static var cachedIsPro: Bool {
        UserDefaults.standard.bool(forKey: proKey)
    }

    /// Long-lived transaction observer. Started once in `init()` so we never
    /// miss a StoreKit redelivery (parental approval completing later, a
    /// purchase on another device syncing down, or an orphan from a previous
    /// run). Retained for the app's lifetime.
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(verificationResult: update)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [PricingConfig.proLifetimeProductID])
            self.product = products.first
            await refreshEntitlement()
        } catch {
            lastError = "Could not load the store right now."
        }
    }

    func purchase() async {
        guard let product else {
            lastError = "Product unavailable. Try again in a moment."
            return
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verificationResult: verification)
            case .userCancelled:
                break
            case .pending:
                // Ask-to-Buy or SCA — we'll be notified via Transaction.updates.
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed. Please try again."
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastError = "Could not restore purchases. Try again later."
        }
    }

    private func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == PricingConfig.proLifetimeProductID,
               tx.revocationDate == nil {
                entitled = true
            }
        }
        setPro(entitled)
    }

    private func handle(verificationResult: VerificationResult<Transaction>) async {
        switch verificationResult {
        case .verified(let tx):
            if tx.productID == PricingConfig.proLifetimeProductID, tx.revocationDate == nil {
                setPro(true)
            } else if tx.revocationDate != nil {
                setPro(false)
            }
            await tx.finish()
        case .unverified:
            // JWS failed — ignore; Apple will redeliver or we'll resync on next launch.
            break
        }
    }

    private func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: Self.proKey)
    }
}
