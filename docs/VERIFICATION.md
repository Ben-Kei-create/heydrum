# Verification record (updated 2026-10-20, after start-delay/large-text features and Codex review fixes)

Environment: Xcode 27.1 (27A9275), iOS Simulator 27.0 "iPhone 18 Pro", iOS deployment target 17.0, Swift 5 mode.
Real device: **none used** (all device-only items are NOT RUN).

## Commands and results
| Command | Result |
|---|---|
| `xcodebuild -scheme HeyDrum -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | PASS |
| `... -only-testing:HeyDrumTests test` (unit + integration, incl. StoreKitTest + real AVSpeechSynthesizer) | PASS — 85 tests, 0 failures |
| `... -only-testing:HeyDrumUITests test` | PASS — 14 tests, 0 failures (one earlier run had 4 simulator-timing flakes; tests were hardened and re-run green) |
| Release build, no secrets | FAIL by design: "Release guard: AD_UNIT_ID is empty" |
| Release build with Google test ids | FAIL by design: "Google TEST ad ids must not be used in Release" |
| Release build with non-test dummy ids passed on the command line | PASS (confirms Release compiles without DEBUG fakes) |
| Static grep (print/NSLog/os_log/URLSession/analytics, `Request()` only empty, no tracked secrets) | clean |

## Test-plan status (docs/09)
PASS (automated, simulator): T-001, T-002, T-006, T-007, T-008, T-009, T-010, T-011, T-012, T-013, T-014, T-015 (repository+settings restart), T-016, T-017, T-018, T-021, T-022, T-023, T-024, T-025, T-026, T-027 (pending, failed), T-028, T-029, T-031, T-033, T-034, T-036, T-037 (guard + grep), T-038, T-040, T-041 (replay does not add rows: PlaybackViewModel replay path), T-042, T-043, T-044 (44pt controls asserted for stop; layout on one device only), T-045 (no photo/instrument assets in bundle).
PARTIAL: T-005 (50 rapid taps, simulator, no crash; audible quality not assessed), T-027 user-cancel and `.unverified` outcomes are code paths without a StoreKitTest trigger → NOT RUN, T-030 (settings persistence PASS; audible 0/70/100% NOT RUN), T-035 (interruption/background logic unit-tested; real phone call NOT RUN).
NOT RUN (device required): T-003, T-004, T-019 (airplane mode), T-020 (voice character / female-robot impression), T-032 (VoiceOver pass; labels and identifiers are set, no human VoiceOver run), T-039 (real ad failure), App Store Sandbox/TestFlight purchase and real banner load.
Real AdMob: only the SDK integration compiles; no ad was loaded in this verification (fakes used for logic; the live banner path was not exercised).

## Known limits / owner decisions
- Large anchored adaptive banner is taller than the old standard banner (ADR-008).
- `currentEntitlements` has no error channel; entitlement cannot be reported `.unavailable` from a StoreKit outage (ADR-010).
- Scheme StoreKit configuration reference (`../../HeyDrum.storekit`) follows Xcode's convention but was not verified by launching from Xcode; the unit tests load the file directly.
- Commits are local; nothing was pushed.


## 2026-10-20 update (supersedes the counts above)
Environment note: a wedged simulator made `xcodebuild test` hang before any test ran (no "Test Case" lines); shutting down/rebooting the simulator fixed it. Codex reported the same class of xcodebuild post-processing hangs.

| Command | Result |
|---|---|
| `-only-testing:HeyDrumTests test` (unit + integration incl. StoreKitTest + real AVSpeechSynthesizer) | PASS — 100 tests, 0 failures |
| `-only-testing:HeyDrumUITests test` | PASS — 17 tests, 0 failures |
| `sh tools/test_release_guard.sh` | PASS — 14/14 (empty, Google test ids, template values, malformed ids, test mode on, Debug unaffected) |
| Release build: no secrets / template values / well-formed dummy ids | FAIL (guard) / FAIL (guard) / PASS, as intended |

Codex 2026-10-20 findings: P0 Release guard, P0 consent gate, P1 save-in-flight vs interruption, P1 preview vs interruption, P1 Dynamic Type, P2 sound script path, P2 UI test structure — all addressed in code with regression tests (see ADR-015). Codex's own StoreKit run could not fetch products on a fresh simulator and hit an Apple-account prompt; the local StoreKit tests here pass but T-026/027/028/029 remain simulator-StoreKitTest evidence only (no App Store sandbox). Not independently re-reviewed by Codex after these fixes.

## 2026-10-20 (later) — ATT / B plan
- Unit + integration: 104 tests, 0 failures (adds AdTrackingPromptTests: ATT after consent and before SDK start; none for denied consent / purchased / unknown entitlement; purchase during the prompt stops before SDK start).
- Real prompt checked once in the iPhone 18 Pro simulator with the live (non-fake) services: Google's consent explainer ("Continue") appeared, then the iOS tracking prompt with the Japanese `NSUserTrackingUsageDescription`. App icon confirmed on the simulator home screen. The full UI suite was not re-run after this change (it uses fake consent and is unaffected by it); simulator only, no device.
