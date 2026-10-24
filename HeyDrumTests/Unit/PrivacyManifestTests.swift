import XCTest
@testable import HeyDrum

/// App Store Connect rejected build 2 with ITMS-91064 ("Invalid tracking information"): the manifest had
/// `NSPrivacyTracking = true` together with an EMPTY `NSPrivacyTrackingDomains` array. Keep the file consistent.
final class PrivacyManifestTests: XCTestCase {
    private func manifest() throws -> [String: Any] {
        let url = try XCTUnwrap(Bundle(for: DrumSoundService.self).url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    func testTrackingDomainsAreNeverAnEmptyArray() throws {
        let m = try manifest()
        if let domains = m["NSPrivacyTrackingDomains"] as? [String] {
            XCTAssertFalse(domains.isEmpty, "an empty NSPrivacyTrackingDomains array triggers ITMS-91064: omit the key instead")
        }
    }

    /// Both directions of Apple's rule: domains listed ⇒ tracking true, and tracking true ⇒ at least one domain.
    func testTrackingFlagAndDomainsAreConsistent() throws {
        let m = try manifest()
        let domains = (m["NSPrivacyTrackingDomains"] as? [String]) ?? []
        let tracking = (m["NSPrivacyTracking"] as? Bool) ?? false
        if !domains.isEmpty { XCTAssertTrue(tracking, "NSPrivacyTracking must be true if domains are listed") }
        if tracking { XCTAssertFalse(domains.isEmpty, "NSPrivacyTracking true needs at least one tracking domain (build 3 was rejected for this)") }
    }

    /// Pinned decision (ADR-025): the app-level flag is false and no domains are listed; the ad SDKs ship their own
    /// manifests, ATT is still requested, and listing Google's ad domains would block ads for users who deny ATT.
    func testAppLevelManifestFollowsAdr025() throws {
        let m = try manifest()
        XCTAssertEqual(m["NSPrivacyTracking"] as? Bool, false)
        XCTAssertNil(m["NSPrivacyTrackingDomains"])
        let apis = try XCTUnwrap(m["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaults = apis.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" }
        XCTAssertEqual(userDefaults?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
    }
}
