import UIKit
import Observation

/// Owns the one shared ad slot's state machine (docs/07 §2). Ads are requested only when the
/// entitlement is verified `.free` AND UMP says `canRequestAds`.
@MainActor @Observable
final class AdMobManager {
    private(set) var status: AdStatus = .entitlementChecking
    private(set) var privacyOptionsRequired = false
    /// Banner requests actually issued (evidence for T-024/T-025).
    private(set) var requestCount = 0
    private(set) var banner: AdBannerControlling?

    @ObservationIgnored private let config: AppConfig
    @ObservationIgnored private let purchase: PurchaseProviding
    @ObservationIgnored private let consent: AdConsentProviding
    @ObservationIgnored private let sdk: AdSDKStarting
    @ObservationIgnored private let makeBanner: @MainActor () -> AdBannerControlling
    @ObservationIgnored private var slotWidth: CGFloat = 0
    @ObservationIgnored private var loadedWidth: CGFloat = 0
    @ObservationIgnored private var consentTask: Task<Void, Never>?
    @ObservationIgnored private var consentGathered = false
    @ObservationIgnored private var started = false

    init(config: AppConfig, purchase: PurchaseProviding, consent: AdConsentProviding, sdk: AdSDKStarting,
         makeBanner: @escaping @MainActor () -> AdBannerControlling = { GoogleBannerController() }) {
        self.config = config
        self.purchase = purchase
        self.consent = consent
        self.sdk = sdk
        self.makeBanner = makeBanner
    }

    /// Whether the shared slot occupies space (purchased → no slot at all).
    var isSlotPresent: Bool { status != .hidden }

    func start() async {
        guard !started else { return }
        started = true
        track()
        evaluate()
        await consentTask?.value
    }

    /// Called by the slot view whenever its width is known / changes.
    func updateSlotWidth(_ width: CGFloat) {
        guard width > 0, abs(width - slotWidth) > 0.5 else { return }
        slotWidth = width
        if status == .loading || status == .visible, abs(loadedWidth - width) > 0.5 { requestBanner() }
    }

    func presentPrivacyOptions() async {
        await consent.presentPrivacyOptions()
        privacyOptionsRequired = consent.privacyOptionsRequired
        reevaluateConsent()
    }

    /// Re-checks the CURRENT consent after the privacy form: revoked → dispose the banner, keep a blank slot;
    /// granted again → resume through the normal flow (no duplicate requests).
    func reevaluateConsent() {
        guard purchase.entitlement == .free else { return }
        switch status {
        case .loading, .visible:
            if !consent.canRequestAds {
                tearDownBanner()
                status = .noFill
            }
        case .noFill:
            if consent.canRequestAds { beginConsentFlow() }
        default:
            break
        }
    }

    // MARK: Internals

    private func track() {
        withObservationTracking {
            _ = purchase.entitlement
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.evaluate()
                self?.track()
            }
        }
    }

    func evaluate() {
        switch purchase.entitlement {
        case .checking:
            tearDownBanner()
            status = .entitlementChecking
        case .unavailable:
            tearDownBanner()
            status = .waiting
        case .purchased:
            consentTask?.cancel()
            tearDownBanner()
            status = .hidden
        case .free:
            guard status != .loading, status != .visible, status != .consentChecking else { return }
            beginConsentFlow()
        }
    }

    private func beginConsentFlow() {
        status = .consentChecking
        consentTask?.cancel()
        consentTask = Task { [weak self] in
            guard let self else { return }
            let canRequest: Bool
            if self.consentGathered {
                canRequest = self.consent.canRequestAds
            } else {
                canRequest = await self.consent.gatherConsent()
                self.consentGathered = true
            }
            self.privacyOptionsRequired = self.consent.privacyOptionsRequired
            // The entitlement may have changed while the consent form was up.
            guard !Task.isCancelled, self.purchase.entitlement == .free else { return }
            guard canRequest else {
                self.status = .noFill
                return
            }
            await self.sdk.start()
            // Re-check the latest state after awaiting: entitlement AND consent may have changed meanwhile.
            guard !Task.isCancelled, self.purchase.entitlement == .free, self.consent.canRequestAds else {
                if self.purchase.entitlement == .free { self.status = .noFill }
                return
            }
            self.status = .loading
            self.requestBanner()
        }
    }

    private func requestBanner() {
        guard status == .loading || status == .visible, slotWidth > 0, !config.adUnitID.isEmpty else { return }
        // Final gate immediately before every request.
        guard purchase.entitlement == .free, consent.canRequestAds else {
            tearDownBanner()
            status = purchase.entitlement == .free ? .noFill : status
            return
        }
        if banner == nil {
            let controller = makeBanner()
            controller.onResult = { [weak self] success in
                guard let self, self.status == .loading || self.status == .visible else { return }
                self.status = success ? .visible : .noFill
            }
            banner = controller
        }
        loadedWidth = slotWidth
        requestCount += 1
        banner?.load(adUnitID: config.adUnitID, width: slotWidth)
    }

    private func tearDownBanner() {
        banner?.invalidate()
        banner = nil
        loadedWidth = 0
    }
}

#if DEBUG
@MainActor
final class FakeConsentService: AdConsentProviding {
    var canRequestAds: Bool
    var privacyOptionsRequired = false
    private(set) var gatherCount = 0
    private(set) var presentOptionsCount = 0

    init(canRequestAds: Bool) { self.canRequestAds = canRequestAds }

    func gatherConsent() async -> Bool { gatherCount += 1; return canRequestAds }
    func presentPrivacyOptions() async { presentOptionsCount += 1 }
}

@MainActor
final class FakeAdSDK: AdSDKStarting {
    private(set) var startCount = 0
    var onStart: (() -> Void)?
    func start() async { startCount += 1; onStart?() }
}

@MainActor
final class FakeBannerController: AdBannerControlling {
    let view = UIView()
    var onResult: ((Bool) -> Void)?
    private(set) var loadCount = 0
    private(set) var lastAdUnitID: String?
    private(set) var invalidated = false
    func load(adUnitID: String, width: CGFloat) { loadCount += 1; lastAdUnitID = adUnitID }
    func invalidate() { invalidated = true }
}
#endif
