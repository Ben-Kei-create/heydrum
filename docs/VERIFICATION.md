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

## 2026-10-21 — cumulative reading display (owner change, ADR-018)
Environment: Xcode 27.1, iPhone 18 Pro / 18 Pro Max simulators, iOS 27.0. The Mac was heavily loaded by other processes during the later runs (UI tests took far longer than usual, one run 800–1000 s); results below are from runs that completed.
| Command | Result |
|---|---|
| `-only-testing:HeyDrumTests test` (fresh simulator boot) | PASS — 120 tests, 0 failures. (One earlier run, on a simulator that had been in use, failed `StoreKitPurchaseTests.testAskToBuyPendingGrantsNothing` because StoreKit products did not load; it passed on a freshly booted simulator.) |
| `-only-testing:HeyDrumUITests test` (full, incl. new reveal/pause/countdown/Dynamic Type tests) | PASS — 25 executed, 5 screenshot-only skipped, 0 failures |
New unit tests: PlaybackRevealTests (14), TextRevealTests (5): empty before speech/countdown, cumulative prefix growth, backward/overlapping/invalid/overflow/stale ranges, pause freezes and resume continues, natural finish shows full text, system cancel/interrupt/stop do not reveal the rest, replay/retry/new session reset, emoji/ZWJ/combining/newline alignment, fallback when no range notifications arrive, 44pt+ font table and Dynamic Type scale.
New UI tests: progressive reveal never rewinds and ends with the full text, display freezes while paused and continues on resume, no text during countdown, 500 characters keep the newest text above the controls, text grows with Dynamic Type.
Visual evidence: `docs/evidence/reading-reveal-sequence.png` (8 consecutive frames, iPhone 18 Pro Max simulator) and the long-text sequence checked during development (auto-scroll follows the newest text).
Not verified: the real `AVSpeechSynthesizer` range-notification granularity on devices/voices (simulator uses fake ranges in UI tests; the real-engine integration test only checks started/finished), VoiceOver by a human, small-iPhone layout on a physical device.

## 2026-10-22 — default max volume, half speed, launch greeting (ADR-019/020)
| Command | Result |
|---|---|
| `-only-testing:HeyDrumTests test` | PASS — 133 tests, 0 failures (new: GreetingTests 11, default-volume and half-speed rate tests; the real-engine range test passed in 6.5 s: real `AVSpeechSynthesizer` sends several forward ranges) |
| `-only-testing:HeyDrumUITests test` (SHOT_DIR set, so screenshot tests ran too) | PASS — 28 tests, 0 failures (new: greeting appears with "ドラム", no controls, closes itself; tap skips it; volume slider shows 100%) |
Evidence: `docs/evidence/launch-greeting.png`. Store screenshots/IAP image recaptured (settings now shows 100% volume).
NOT verified: the actual sound of Eddy (only names/ids and event flow; Eddy is matched by name and the Mac lists `Eddy` as ja-JP, the simulator voice list was not printed), whether the new rates really sound like half speed (T-057 needs ears on a device), the greeting on a physical device. The App Preview video was not re-made (it still shows 70%-era settings and no greeting).

## 2026-10-22 (later) — text size slider, left pause button, seconds counter, fonts, speech speed measurement
| Command | Result |
|---|---|
| `-only-testing:HeyDrumTests test` | PASS — 139 tests, 1 skipped (rate sweep calibration probe, env-gated), 0 failures |
| `-only-testing:HeyDrumUITests/HeyDrumUITests` + `ScreenshotTests/testFontSamples` | PASS — 25 tests, 0 failures |
Speech speed, measured on the real engine (same 31-character sentence; duration vs. old normal rate 0.50):
- iOS simulator voice (Kyoko compact): 0.50 → 5.4 s; new slow 0.0 → 9.7 s (1.8×); normal 0.10 → 8.1 s (1.5×); fast 0.25 → 7.0 s (1.3×). The first attempt (normal 0.25) was only 1.3× slower, which is why the rates were changed to 0.0/0.10/0.25.
- Mac, Eddy: 0.50 → 7.4 s; 0.25 → 10.8 s; 0.10 → 14.2 s (1.9×); 0.0 → 16.7 s (2.3×). Mac, Kyoko: 0.10 → 1.5×; 0.0 → 1.7×.
=> "exactly half the speed" is reached for Eddy at normal, but not for Kyoko (about 1.5×). Phrase pauses would be needed for more (not implemented).
Evidence: `docs/evidence/reading-fonts.png` (4 fonts, left pause button, bottom controls). Not verified: sound/feel on a physical device (T-057), VoiceOver by a human.

## 2026-10-22 (Codex review of 15371f8 addressed — ADR-023)
- `-only-testing:HeyDrumTests test`: PASS — 144 tests, 1 skipped (env-gated calibration probe), 0 failures. New: 5 pause-before-first-range regression tests (T-048 × T-052).
- Pause-related UI tests (left pause button, reveal freezes on pause, label toggle): PASS (3).
- Speed test (median of 3 alternating rounds after warm-up): voice=Kyoko, old 4.02 s, slow 7.25 s, normal 6.04 s (1.50×), fast 5.23 s; samples within ±0.01 s on an idle machine.
- Docs: T-055 and T-058–T-061 rows fixed in docs/09.
