import XCTest
@testable import HeyDrum

@MainActor
final class AdMobManagerTests: XCTestCase {
    @MainActor private struct Rig {
        let ads: AdMobManager
        let purchase: FakePurchaseService
        let consent: FakeConsentService
        let sdk: FakeAdSDK
        var banner: FakeBannerController? { ads.banner as? FakeBannerController }
    }

    private func rig(_ entitlement: EntitlementState, canRequestAds: Bool = true, adUnitID: String = "ca-app-pub-3940256099942544/2435281174") -> Rig {
        let purchase = FakePurchaseService(entitlement: entitlement)
        let consent = FakeConsentService(canRequestAds: canRequestAds)
        let sdk = FakeAdSDK()
        let config = AppConfig(adUnitID: adUnitID, adsTestMode: true, removeAdsProductID: "p")
        let ads = AdMobManager(config: config, purchase: purchase, consent: consent, sdk: sdk, makeBanner: { FakeBannerController() })
        ads.updateSlotWidth(390)
        return Rig(ads: ads, purchase: purchase, consent: consent, sdk: sdk)
    }

    // T-025
    func testNoRequestWhileEntitlementIsChecking() async {
        let r = rig(.checking)
        await r.ads.start()
        XCTAssertEqual(r.ads.status, .entitlementChecking)
        XCTAssertTrue(r.ads.isSlotPresent, "slot space is reserved while checking")
        XCTAssertEqual(r.consent.gatherCount, 0)
        XCTAssertEqual(r.sdk.startCount, 0)
        XCTAssertEqual(r.ads.requestCount, 0)
        XCTAssertNil(r.banner)
    }

    func testNoRequestWhileEntitlementUnavailable() async {
        let r = rig(.unavailable)
        await r.ads.start()
        XCTAssertEqual(r.ads.status, .waiting)
        XCTAssertTrue(r.ads.isSlotPresent)
        XCTAssertEqual(r.ads.requestCount, 0)
        XCTAssertEqual(r.sdk.startCount, 0)
    }

    // T-024
    func testNoRequestWithoutConsent() async {
        let r = rig(.free, canRequestAds: false)
        await r.ads.start()
        XCTAssertEqual(r.consent.gatherCount, 1)
        XCTAssertEqual(r.ads.status, .noFill)
        XCTAssertTrue(r.ads.isSlotPresent, "blank slot is kept")
        XCTAssertEqual(r.sdk.startCount, 0, "SDK is not started before consent")
        XCTAssertEqual(r.ads.requestCount, 0)
        XCTAssertNil(r.banner)
    }

    func testRequestsOnceAfterConsentAndEntitlementAreVerified() async {
        let r = rig(.free)
        await r.ads.start()
        XCTAssertEqual(r.sdk.startCount, 1)
        XCTAssertEqual(r.ads.status, .loading)
        XCTAssertEqual(r.ads.requestCount, 1)
        XCTAssertEqual(r.banner?.loadCount, 1)
        XCTAssertEqual(r.banner?.lastAdUnitID, "ca-app-pub-3940256099942544/2435281174")
        r.banner?.onResult?(true)
        XCTAssertEqual(r.ads.status, .visible)
        r.ads.updateSlotWidth(390)       // same width → no new request
        XCTAssertEqual(r.ads.requestCount, 1)
    }

    // T-039 / ER-08
    func testLoadFailureKeepsBlankSlot() async {
        let r = rig(.free)
        await r.ads.start()
        r.banner?.onResult?(false)
        XCTAssertEqual(r.ads.status, .noFill)
        XCTAssertTrue(r.ads.isSlotPresent)
    }

    func testEmptyAdUnitIDNeverRequests() async {
        let r = rig(.free, adUnitID: "")
        await r.ads.start()
        XCTAssertEqual(r.ads.requestCount, 0)
    }

    func testPurchasedFromStartNeverTouchesConsentOrSDK() async {
        let r = rig(.purchased)
        await r.ads.start()
        XCTAssertEqual(r.ads.status, .hidden)
        XCTAssertFalse(r.ads.isSlotPresent)
        XCTAssertEqual(r.consent.gatherCount, 0)
        XCTAssertEqual(r.sdk.startCount, 0)
        XCTAssertEqual(r.ads.requestCount, 0)
    }

    // T-026
    func testPurchaseRemovesSlotAndDestroysBannerImmediately() async {
        let r = rig(.free)
        await r.ads.start()
        r.banner?.onResult?(true)
        let banner = r.banner
        r.purchase.entitlement = .purchased
        await waitUntil("hidden") { r.ads.status == .hidden }
        XCTAssertFalse(r.ads.isSlotPresent)
        XCTAssertNil(r.ads.banner)
        XCTAssertEqual(banner?.invalidated, true)
        XCTAssertEqual(r.ads.requestCount, 1, "no further requests after purchase")
    }

    func testPurchaseWhileConsentFormIsUpNeverLoads() async {
        let r = rig(.checking)
        await r.ads.start()
        r.purchase.entitlement = .free
        r.purchase.entitlement = .purchased
        await settle()
        XCTAssertEqual(r.ads.status, .hidden)
        XCTAssertEqual(r.ads.requestCount, 0)
    }

    // T-029
    func testRefundBringsAdsBackThroughConsentCheck() async {
        let r = rig(.purchased)
        await r.ads.start()
        XCTAssertEqual(r.ads.status, .hidden)
        r.purchase.entitlement = .free
        await waitUntil("loading") { r.ads.status == .loading }
        XCTAssertTrue(r.ads.isSlotPresent)
        XCTAssertEqual(r.ads.requestCount, 1)
    }

    func testEntitlementResolvingAfterLaunchStartsTheFlowOnlyThen() async {
        let r = rig(.checking)
        await r.ads.start()
        XCTAssertEqual(r.ads.requestCount, 0)
        r.purchase.entitlement = .free
        await waitUntil("loading") { r.ads.status == .loading }
        XCTAssertEqual(r.consent.gatherCount, 1)
        XCTAssertEqual(r.ads.requestCount, 1)
    }

    func testPrivacyOptionsFlagIsExposed() async {
        let r = rig(.free)
        r.consent.privacyOptionsRequired = true
        await r.ads.start()
        XCTAssertTrue(r.ads.privacyOptionsRequired)
        await r.ads.presentPrivacyOptions()
        XCTAssertEqual(r.consent.presentOptionsCount, 1)
    }
}
