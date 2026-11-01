import Foundation

/// Identifiers come from build configuration (Config/*.xcconfig → Info.plist), never from source.
struct AppConfig: Equatable, Sendable {
    let adUnitID: String
    let adsTestMode: Bool
    let removeAdsProductID: String

    /// Public policy page (GitHub Pages, published 2026-10-22). Shown as a link in Settings > プライバシーポリシー.
    static let privacyPolicyURL: URL? = URL(string: "https://www.givetex.org/apps/heydrum/privacy/")

    static func from(bundle: Bundle = .main) -> AppConfig {
        func string(_ key: String) -> String {
            (bundle.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        return AppConfig(
            adUnitID: string("HeyDrumAdUnitID"),
            adsTestMode: string("HeyDrumAdsTestMode").uppercased() == "YES",
            removeAdsProductID: string("HeyDrumRemoveAdsProductID")
        )
    }
}
