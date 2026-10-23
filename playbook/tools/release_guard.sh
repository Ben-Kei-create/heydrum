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
exit 0
