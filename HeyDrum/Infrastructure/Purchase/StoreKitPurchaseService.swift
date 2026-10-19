import Foundation
import Observation
import StoreKit

/// Non-consumable "remove ads" (docs/06 §4–5). The entitlement is derived ONLY from verified,
/// non-revoked `Transaction.currentEntitlements`; nothing is cached in UserDefaults.
@MainActor @Observable
final class StoreKitPurchaseService: PurchaseProviding {
    private(set) var entitlement: EntitlementState = .checking
    private(set) var productState: ProductLoadState = .loading
    private(set) var isBusy = false
    private(set) var statusMessage: String?

    @ObservationIgnored private let productID: String
    @ObservationIgnored private var product: Product?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(productID: String) { self.productID = productID }

    deinit { updatesTask?.cancel() }

    func startObservingTransactions() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(update: result)
            }
        }
    }

    func stopObservingTransactions() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    /// Revocations (refunds) arrive here too; re-evaluating entitlements covers both directions.
    func handle(update result: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = result, transaction.productID == productID {
            await transaction.finish()
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        guard !productID.isEmpty else {
            entitlement = .unavailable
            return
        }
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        entitlement = owned ? .purchased : .free
    }

    func loadProduct() async {
        guard !productID.isEmpty else { productState = .unavailable; return }
        do {
            let products = try await Product.products(for: [productID])
            if let found = products.first, found.type == .nonConsumable {
                product = found
                productState = .loaded(displayPrice: found.displayPrice)   // StoreKit's price is the only source
            } else {
                productState = .unavailable
            }
        } catch {
            productState = .unavailable
        }
    }

    func purchaseRemoveAds() async -> PurchaseOutcome {
        guard !isBusy else { return .failed("処理中です") }
        guard let product else {
            statusMessage = "現在購入情報を取得できません"
            return .failed("現在購入情報を取得できません")
        }
        isBusy = true
        statusMessage = nil
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    guard transaction.productID == productID, transaction.revocationDate == nil else {
                        statusMessage = "購入を確認できませんでした"
                        return .failed("購入を確認できませんでした")
                    }
                    await transaction.finish()
                    await refreshEntitlements()
                    return entitlement == .purchased ? .purchased : .failed("購入を確認できませんでした")
                case .unverified:
                    statusMessage = "購入を確認できませんでした"
                    return .failed("購入を確認できませんでした")
                }
            case .pending:
                statusMessage = "購入は保留中です。承認されると自動で反映されます。"
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                statusMessage = "購入を完了できませんでした"
                return .failed("購入を完了できませんでした")
            }
        } catch {
            statusMessage = "購入を完了できませんでした。もう一度お試しください。"
            return .failed("購入を完了できませんでした")
        }
    }

    func restore() async -> RestoreOutcome {
        guard !isBusy else { return .failed }
        isBusy = true
        statusMessage = nil
        defer { isBusy = false }
        do {
            try await AppStore.sync()
        } catch {
            statusMessage = "購入情報を更新できませんでした"
            return .failed
        }
        await refreshEntitlements()
        if entitlement == .purchased { return .restored }
        statusMessage = "復元できる購入が見つかりません"
        return .nothingToRestore
    }
}
