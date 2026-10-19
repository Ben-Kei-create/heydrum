import UIKit

enum AdStatus: Equatable {
    case entitlementChecking   // slot reserved, no request
    case hidden                // purchased: slot removed
    case waiting               // entitlement unknown: slot reserved, no request
    case consentChecking
    case loading
    case visible
    case noFill                // consent not granted / offline / no inventory: blank slot kept
}

@MainActor
protocol AdConsentProviding: AnyObject {
    /// Updates consent info and presents the form if required. Returns `canRequestAds`.
    func gatherConsent() async -> Bool
    var canRequestAds: Bool { get }
    var privacyOptionsRequired: Bool { get }
    func presentPrivacyOptions() async
}

@MainActor
protocol AdSDKStarting: AnyObject {
    func start() async
}

@MainActor
protocol AdBannerControlling: AnyObject {
    var view: UIView { get }
    var onResult: ((Bool) -> Void)? { get set }
    /// Issues exactly one ad request. Never receives user content.
    func load(adUnitID: String, width: CGFloat)
    func invalidate()
}

enum AdRootViewController {
    @MainActor
    static func current() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
