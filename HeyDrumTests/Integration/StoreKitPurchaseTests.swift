import XCTest
import StoreKit
import StoreKitTest
@testable import HeyDrum

/// Runs against Xcode's local StoreKit test environment (HeyDrum.storekit). Not the App Store sandbox.
@MainActor
final class StoreKitPurchaseTests: XCTestCase {
    private let productID = "example.heydrum.dev.remove_ads"
    private var session: SKTestSession!

    override func setUp() async throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HeyDrum.storekit")
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        await waitForCleanEntitlements()
    }

    /// StoreKit state is process-wide; make sure the previous test's transactions are really gone.
    private func waitForCleanEntitlements() async {
        for _ in 0..<50 {
            var any = false
            for await _ in Transaction.currentEntitlements { any = true }
            if !any { return }
            session.clearTransactions()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    override func tearDown() async throws {
        created.forEach { $0.stopObservingTransactions() }
        created.removeAll()
        session.clearTransactions()
        session = nil
    }

    private var created: [StoreKitPurchaseService] = []

    private func service(productID id: String? = nil) -> StoreKitPurchaseService {
        let s = StoreKitPurchaseService(productID: id ?? productID)
        created.append(s)
        return s
    }

    /// The first StoreKit call after a cold simulator boot can race the test session; retry briefly.
    private func loadProduct(_ s: StoreKitPurchaseService) async {
        for _ in 0..<10 {
            await s.loadProduct()
            if case .loaded = s.productState { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    func testProductLoadsWithStoreKitDisplayPrice() async {
        let s = service()
        await loadProduct(s)
        guard case .loaded(let price) = s.productState else { return XCTFail("expected loaded, got \(s.productState)") }
        XCTAssertTrue(price.contains("480"), "price comes from StoreKit (\(price))")
    }

    func testUnknownProductIDIsUnavailableAndPurchaseIsRefused() async {
        let s = service(productID: "no.such.product")
        await s.loadProduct()
        XCTAssertEqual(s.productState, .unavailable)
        let outcome = await s.purchaseRemoveAds()
        XCTAssertEqual(outcome, .failed("現在購入情報を取得できません"))
        XCTAssertEqual(s.entitlement, .checking, "no purchase → entitlement untouched")
    }

    func testEmptyProductIDIsUnavailable() async {
        let s = service(productID: "")
        await s.refreshEntitlements()
        XCTAssertEqual(s.entitlement, .unavailable)
    }

    func testFreshInstallIsFree() async {
        let s = service()
        await s.refreshEntitlements()
        XCTAssertEqual(s.entitlement, .free)
    }

    // T-026
    func testVerifiedPurchaseGrantsEntitlementAndRemovesAdSlot() async {
        let s = service()
        await loadProduct(s)
        await s.refreshEntitlements()
        let consent = FakeConsentService(canRequestAds: true)
        let ads = AdMobManager(config: AppConfig(adUnitID: "u", adsTestMode: true, removeAdsProductID: productID),
                               purchase: s, consent: consent, sdk: FakeAdSDK(), makeBanner: { FakeBannerController() })
        ads.updateSlotWidth(390)
        await ads.start()
        XCTAssertEqual(ads.status, .loading)

        let outcome = await s.purchaseRemoveAds()
        XCTAssertEqual(outcome, .purchased)
        XCTAssertEqual(s.entitlement, .purchased)
        await waitUntil("slot removed") { ads.status == .hidden }
        XCTAssertFalse(ads.isSlotPresent)

        // "restart": a brand-new service derives the entitlement from StoreKit alone.
        let relaunched = service()
        await relaunched.refreshEntitlements()
        XCTAssertEqual(relaunched.entitlement, .purchased)
    }

    // T-027 (pending)
    func testAskToBuyPendingGrantsNothing() async {
        session.askToBuyEnabled = true
        let s = service()
        await loadProduct(s)
        await s.refreshEntitlements()
        let outcome = await s.purchaseRemoveAds()
        XCTAssertEqual(outcome, .pending)
        XCTAssertEqual(s.entitlement, .free)
        XCTAssertNotNil(s.statusMessage)
    }

    // T-027 (failure)
    func testFailedTransactionGrantsNothingAndAllowsRetry() async throws {
        try await session.setSimulatedError(.generic(.unknown), forAPI: .purchase)
        let s = service()
        await loadProduct(s)
        await s.refreshEntitlements()
        let outcome = await s.purchaseRemoveAds()
        if case .failed = outcome {} else { XCTFail("expected failed, got \(outcome)") }
        XCTAssertEqual(s.entitlement, .free)
        XCTAssertFalse(s.isBusy)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        let retry = await s.purchaseRemoveAds()
        XCTAssertEqual(retry, .purchased)
    }

    // T-028
    func testExplicitRestoreRestoresEntitlement() async throws {
        _ = try await session.buyProduct(identifier: productID)
        let s = service()                        // new install: nothing refreshed yet
        let outcome = await s.restore()
        XCTAssertEqual(outcome, .restored)
        XCTAssertEqual(s.entitlement, .purchased)
    }

    func testRestoreWithoutPurchaseReportsNothingToRestore() async {
        let s = service()
        let outcome = await s.restore()
        XCTAssertEqual(outcome, .nothingToRestore)
        XCTAssertEqual(s.entitlement, .free)
        XCTAssertEqual(s.statusMessage, "復元できる購入が見つかりません")
    }

    func testRestoreIsNotCalledByRefreshOrLaunchPaths() async {
        // `AppStore.sync()` must only run from the explicit restore tap: startUp-style calls never invoke it.
        let fake = FakePurchaseService(entitlement: .free)
        fake.startObservingTransactions()
        await fake.loadProduct()
        await fake.refreshEntitlements()
        XCTAssertEqual(fake.restoreCount, 0)
    }

    // T-029
    func testRefundRevokesEntitlementViaTransactionUpdates() async throws {
        let s = service()
        s.startObservingTransactions()
        await s.refreshEntitlements()
        let transaction = try await session.buyProduct(identifier: productID)
        await s.refreshEntitlements()
        XCTAssertEqual(s.entitlement, .purchased)

        try await session.refundTransaction(identifier: UInt(transaction.id))
        await waitUntil("entitlement revoked", timeout: 10) { s.entitlement == .free }
        XCTAssertEqual(s.entitlement, .free)
    }
}
