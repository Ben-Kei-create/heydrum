import Foundation

/// Identifiers come from build configuration (Config/*.xcconfig → Info.plist), never from source.
struct AppConfig: Equatable, Sendable {
    let adUnitID: String
    let adsTestMode: Bool
    let removeAdsProductID: String

    /// Owner must set this before release (docs/11). While nil, Settings shows the in-app summary only.
    static let privacyPolicyURL: URL? = nil

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
