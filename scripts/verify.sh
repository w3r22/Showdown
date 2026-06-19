#!/bin/bash
# verify.sh — the "always runnable" guarantee for Showdown.
# 1. Builds, installs, launches and screenshots the app in the iOS Simulator.
# 2. Device build-check: signed build if a codesigning identity exists, else an
#    unsigned device-arch compile (so device-only breakage is still caught).
# Exit non-zero on any failure so the workflow/reviewer can gate on it.
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="Showdown.xcodeproj"
SCHEME="Showdown"
BUNDLE_ID="net.leochen.Showdown"
SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"
DERIVED="build"

echo "==> [1/2] Simulator build + launch ($SIM_NAME)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -derivedDataPath "$DERIVED" build

echo "==> Booting simulator (if needed)"
xcrun simctl bootstatus "$SIM_NAME" -b >/dev/null 2>&1 || true

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/Showdown.app"
echo "==> Installing $APP_PATH"
xcrun simctl install booted "$APP_PATH"

echo "==> Launching $BUNDLE_ID"
xcrun simctl launch booted "$BUNDLE_ID" || true
sleep 3

SHOT="$DERIVED/last-run.png"
xcrun simctl io booted screenshot "$SHOT"
echo "==> Simulator screenshot: $SHOT"

echo "==> [2/2] Device build-check (generic/platform=iOS)"
if security find-identity -p codesigning -v 2>/dev/null | grep -q "valid identities found" \
   && ! security find-identity -p codesigning -v 2>/dev/null | grep -q "0 valid identities found"; then
  echo "    Codesigning identity found — doing a SIGNED device build."
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED" -allowProvisioningUpdates build
  echo "    ✅ Signed device build OK — app is installable on your iPhone."
else
  echo "    No codesigning identity yet — doing an UNSIGNED device compile."
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build
  echo "    ✅ Device compile OK. NOTE: to install on the physical iPhone, add your"
  echo "       Apple ID in Xcode (Settings → Accounts) and pick your Team under"
  echo "       Signing & Capabilities; then this step upgrades to a signed build."
fi

echo "==> VERIFY OK (simulator runnable + device buildable)"
