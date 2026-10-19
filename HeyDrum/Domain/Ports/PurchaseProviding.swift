import Foundation

enum EntitlementState: Equatable, Sendable { case checking, free, purchased, unavailable }

enum PurchaseOutcome: Equatable, Sendable {
    case purchased, pending, cancelled
    case failed(String)
}

enum ProductLoadState: Equatable, Sendable {
    case loading
    case loaded(displayPrice: String)
    case unavailable
}

enum RestoreOutcome: Equatable, Sendable { case restored, nothingToRestore, failed }

@MainActor
protocol PurchaseProviding: AnyObject {
    var entitlement: EntitlementState { get }
    var productState: ProductLoadState { get }
    var isBusy: Bool { get }
    var statusMessage: String? { get }
    func startObservingTransactions()
    func refreshEntitlements() async
    func loadProduct() async
    func purchaseRemoveAds() async -> PurchaseOutcome
    /// Only ever called from the explicit "購入を復元" tap (`AppStore.sync()`).
    func restore() async -> RestoreOutcome
}
