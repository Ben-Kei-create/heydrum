#!/bin/sh
# Release guard: fails the Release build while any id is empty, a Google TEST id, a documented template
# value, or malformed. It checks FORMAT only; it cannot prove the ids belong to the owner's accounts.
[ "$CONFIGURATION" = "Release" ] || exit 0
fail() { echo "error: Release guard: $1 (see Config/Config.example.xcconfig)"; exit 1; }
for v in AD_UNIT_ID GAD_APPLICATION_IDENTIFIER IN_APP_PURCHASE_PRODUCT_ID HEYDRUM_BUNDLE_ID; do
  eval "val=\${$v}"
  [ -n "$val" ] || fail "$v is empty"
done
case "$AD_UNIT_ID$GAD_APPLICATION_IDENTIFIER" in *3940256099942544*) fail "Google TEST ad ids must not be used in Release";; esac
case "$AD_UNIT_ID$GAD_APPLICATION_IDENTIFIER$IN_APP_PURCHASE_PRODUCT_ID$HEYDRUM_BUNDLE_ID" in
  *XXXX*|*YYYY*|*ZZZZ*|*[Yy]ourcompany*|*example*|*EXAMPLE*|*REPLACE*|*placeholder*) fail "template/placeholder value left in Release settings";;
esac
echo "$AD_UNIT_ID" | grep -Eq '^ca-app-pub-[0-9]{16}/[0-9]{10}$' || fail "AD_UNIT_ID is not a valid AdMob unit id (ca-app-pub-<16 digits>/<10 digits>)"
echo "$GAD_APPLICATION_IDENTIFIER" | grep -Eq '^ca-app-pub-[0-9]{16}~[0-9]{10}$' || fail "GAD_APPLICATION_IDENTIFIER is not a valid AdMob app id (ca-app-pub-<16 digits>~<10 digits>)"
echo "$HEYDRUM_BUNDLE_ID" | grep -Eq '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$' || fail "HEYDRUM_BUNDLE_ID is not a valid reverse-DNS identifier"
echo "$IN_APP_PURCHASE_PRODUCT_ID" | grep -Eq '^[A-Za-z0-9_.-]+$' || fail "IN_APP_PURCHASE_PRODUCT_ID has invalid characters"
[ "$ADS_TEST_MODE" = "NO" ] || fail "ADS_TEST_MODE must be NO in Release"
# Privacy manifest consistency (App Store Connect ITMS-91064). MANIFEST can be overridden for tests.
MANIFEST="${MANIFEST:-$SRCROOT/HeyDrum/Resources/PrivacyInfo.xcprivacy}"
if [ -f "$MANIFEST" ]; then
  PB=/usr/libexec/PlistBuddy
  tracking=$($PB -c "Print :NSPrivacyTracking" "$MANIFEST" 2>/dev/null || echo false)
  if $PB -c "Print :NSPrivacyTrackingDomains" "$MANIFEST" >/dev/null 2>&1; then
    n=$($PB -c "Print :NSPrivacyTrackingDomains" "$MANIFEST" | grep -c '^    ' || true)
    [ "$n" -gt 0 ] || fail "PrivacyInfo.xcprivacy has an EMPTY NSPrivacyTrackingDomains array (remove the key) - ITMS-91064"
    [ "$tracking" = "true" ] || fail "PrivacyInfo.xcprivacy lists tracking domains but NSPrivacyTracking is not true - ITMS-91064"
  else
    [ "$tracking" != "true" ] || fail "PrivacyInfo.xcprivacy has NSPrivacyTracking=true without any tracking domain - ITMS-91064"
  fi
fi
exit 0
