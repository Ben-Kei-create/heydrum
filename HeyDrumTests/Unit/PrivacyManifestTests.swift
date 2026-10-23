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

    func testTrackingFlagIsTrueWheneverDomainsAreListed() throws {
        let m = try manifest()
        if let domains = m["NSPrivacyTrackingDomains"] as? [String], !domains.isEmpty {
            XCTAssertEqual(m["NSPrivacyTracking"] as? Bool, true, "NSPrivacyTracking must be true if domains are listed")
        }
    }

    func testRequiredReasonDeclarationsAreWellFormed() throws {
        let m = try manifest()
        XCTAssertEqual(m["NSPrivacyTracking"] as? Bool, true, "personalised ads with ATT (ADR-017)")
        let apis = try XCTUnwrap(m["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaults = apis.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" }
        XCTAssertEqual(userDefaults?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
    }
}
