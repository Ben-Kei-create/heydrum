import GoogleMobileAds
import UIKit
import UserMessagingPlatform
import AppTrackingTransparency

/// Thin wrappers over Google Mobile Ads SDK 13.x / UMP so the rest of the app stays SDK-free.

@MainActor
final class GoogleMobileAdsStarter: AdSDKStarting {
    private var started = false

    func start() async {
        guard !started else { return }
        started = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            MobileAds.shared.start { _ in continuation.resume() }
        }
    }
}

@MainActor
final class UMPConsentService: AdConsentProviding {
    var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }
    var privacyOptionsRequired: Bool { ConsentInformation.shared.privacyOptionsRequirementStatus == .required }

    func gatherConsent() async -> Bool {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in continuation.resume() }
        }
        if let viewController = AdRootViewController.current() {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                ConsentForm.loadAndPresentIfRequired(from: viewController) { _ in continuation.resume() }
            }
        }
        return ConsentInformation.shared.canRequestAds
    }

    /// iOS only shows the ATT dialog while the app is active, so wait for that first.
    func requestTrackingAuthorization() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        for _ in 0..<50 where UIApplication.shared.applicationState != .active {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        guard UIApplication.shared.applicationState == .active else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    func presentPrivacyOptions() async {
        guard let viewController = AdRootViewController.current() else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentForm.presentPrivacyOptionsForm(from: viewController) { _ in continuation.resume() }
        }
    }
}

/// Anchored adaptive banner. The request carries no targeting data from the app (no user text).
@MainActor
final class GoogleBannerController: NSObject, AdBannerControlling, BannerViewDelegate {
    private let banner = BannerView()
    var onResult: ((Bool) -> Void)?
    var view: UIView { banner }

    func load(adUnitID: String, width: CGFloat) {
        banner.adUnitID = adUnitID
        banner.rootViewController = AdRootViewController.current()
        banner.adSize = AdSizing.adSize(forWidth: width)
        banner.delegate = self
        banner.load(Request())
    }

    func invalidate() {
        banner.delegate = nil
        banner.removeFromSuperview()
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) { onResult?(true) }
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) { onResult?(false) }
}

enum AdSizing {
    static let minimumHeight: CGFloat = 50

    static func adSize(forWidth width: CGFloat) -> AdSize {
        largePortraitAnchoredAdaptiveBanner(width: max(width, 320))
    }

    /// Slot height depends only on the available width, so every screen shares the same slot.
    static func height(forWidth width: CGFloat) -> CGFloat {
        max(minimumHeight, adSize(forWidth: width).size.height)
    }
}
