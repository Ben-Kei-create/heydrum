#!/bin/sh
# Regression test for tools/release_guard.sh (T-037). Usage: sh tools/test_release_guard.sh
G="$(dirname "$0")/release_guard.sh"; pass=0; failn=0
run() { # name expect(0|1) AD APP PRODUCT BUNDLE TESTMODE
  CONFIGURATION=Release AD_UNIT_ID="$3" GAD_APPLICATION_IDENTIFIER="$4" IN_APP_PURCHASE_PRODUCT_ID="$5" HEYDRUM_BUNDLE_ID="$6" ADS_TEST_MODE="$7" sh "$G" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$2" ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: $1 (exit $rc, expected $2)"; fi
}
U=ca-app-pub-1111111111111111/2222222222; A=ca-app-pub-1111111111111111~3333333333; P=com.acme.heydrum.remove_ads; B=com.acme.heydrum
run valid 0 $U $A $P $B NO
run empty-unit 1 "" $A $P $B NO
run empty-bundle 1 $U $A $P "" NO
run google-test-unit 1 ca-app-pub-3940256099942544/2435281174 $A $P $B NO
run google-test-app 1 $U ca-app-pub-3940256099942544~1458002511 $P $B NO
run template-unit 1 ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY $A $P $B NO
run template-app 1 $U ca-app-pub-XXXXXXXXXXXXXXXX~ZZZZZZZZZZ $P $B NO
run template-bundle 1 $U $A com.yourcompany.heydrum.remove_ads com.yourcompany.heydrum NO
run example-product 1 $U $A example.heydrum.dev.remove_ads $B NO
run malformed-unit 1 ca-app-pub-123/456 $A $P $B NO
run malformed-app 1 $U ca-app-pub-1111111111111111/3333333333 $P $B NO
run bad-bundle 1 $U $A $P "nodots" NO
run test-mode-on 1 $U $A $P $B YES
# Debug is never blocked
CONFIGURATION=Debug AD_UNIT_ID="" sh "$G" >/dev/null 2>&1 && pass=$((pass+1)) || { failn=$((failn+1)); echo "FAIL: debug blocked"; }
# Privacy manifest consistency (ITMS-91064)
T=$(mktemp -d)
mk() { # name tracking(true|false) domains-xml
  cat > "$T/$1.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>NSPrivacyTracking</key><$2/>$3</dict></plist>
PL
}
mrun() { # name expect
  CONFIGURATION=Release MANIFEST="$T/$1.plist" AD_UNIT_ID=$U GAD_APPLICATION_IDENTIFIER=$A IN_APP_PURCHASE_PRODUCT_ID=$P HEYDRUM_BUNDLE_ID=$B ADS_TEST_MODE=NO sh "$G" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$2" ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: manifest $1 (exit $rc, expected $2)"; fi
}
mk false-absent false ""
mk true-absent true ""
mk false-empty false "<key>NSPrivacyTrackingDomains</key><array/>"
mk true-empty true "<key>NSPrivacyTrackingDomains</key><array/>"
mk false-listed false "<key>NSPrivacyTrackingDomains</key><array><string>example.net</string></array>"
mk true-listed true "<key>NSPrivacyTrackingDomains</key><array><string>example.net</string></array>"
mrun false-absent 0
mrun true-absent 1
mrun false-empty 1
mrun true-empty 1
mrun false-listed 1
mrun true-listed 0
rm -rf "$T"
echo "release_guard tests: $pass passed, $failn failed"; [ "$failn" = 0 ]
