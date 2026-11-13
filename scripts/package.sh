#!/bin/bash
set -euo pipefail
node --input-type=module -e 'import {signingMode} from "./scripts/prepare.mjs"; signingMode(process.env)'
[[ $(uname -s) == Darwin ]] || { echo 'BLOCKED: macOS packaging required' >&2; exit 1; }
export PINK_VERSION=${PINK_VERSION:-0.0.0}
# Numeric CFBundleVersion, independent from marketing version; CI run number or local 1.
PINK_BUILD=1
if [[ -n ${GITHUB_RUN_NUMBER:-} ]]; then
  if [[ ! $GITHUB_RUN_NUMBER =~ ^[0-9]{1,8}$ ]] || (( GITHUB_RUN_NUMBER >= 99990000 )); then
    echo 'CI build number out of range' >&2; exit 1
  fi
  PINK_BUILD="$((GITHUB_RUN_NUMBER / 10000 + 1)).$((GITHUB_RUN_NUMBER / 100 % 100)).$((GITHUB_RUN_NUMBER % 100))"
fi
export PINK_BUILD
mode=${SIGNING_MODE:-adhoc}
keychain=''
cleanup() {
  if [[ -n $keychain ]]; then security delete-keychain "$keychain" >/dev/null 2>&1 || true; fi
  if [[ -n ${secret_dir:-} ]]; then rm -rf "$secret_dir"; fi
}
trap cleanup EXIT
bash scripts/build.sh
app=build/DerivedData/Build/Products/Release/Pink.app
mkdir -p dist
# Remove only generated packages from the previous product name.
rm -f dist/RefPaste-*.zip dist/RefPaste-*.dmg
rm -f dist/Pink-*.zip dist/Pink-*.dmg dist/SHA256SUMS dist/build-info.json
notarization=none
if [[ $mode == developer-id ]]; then
  secret_dir=$(mktemp -d "${PINK_TEMP_ROOT:-${TMPDIR:-/tmp}}/pink-signing.XXXXXX")
  keychain="$secret_dir/signing.keychain-db"
  password=$(openssl rand -hex 32)
  security create-keychain -p "$password" "$keychain"
  echo signing-keychain-created
  security set-keychain-settings -lut 21600 "$keychain"
  security unlock-keychain -p "$password" "$keychain"
  printf '%s' "$APPLE_CERTIFICATE_P12_BASE64" | /usr/bin/base64 -D > "$secret_dir/cert.p12"
  security import "$secret_dir/cert.p12" -k "$keychain" -P "$APPLE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign >/dev/null
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
  codesign --force --options runtime --timestamp --keychain "$keychain" --sign "$APPLE_SIGNING_IDENTITY" "$app"
  ditto -c -k --keepParent "$app" "$secret_dir/notarize.zip"
  xcrun notarytool submit "$secret_dir/notarize.zip" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  spctl --assess --type execute --verbose "$app"
  notarization=accepted
else
  codesign --force --options runtime --sign - "$app"
fi
suffix=$mode
zip="dist/Pink-$PINK_VERSION-$suffix.zip"
dmg="dist/Pink-$PINK_VERSION-$suffix.dmg"
ditto -c -k --keepParent "$app" "$zip"
stage=$(mktemp -d)
trap 'rm -rf "$stage"; cleanup' EXIT
ditto "$app" "$stage/Pink.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname Pink -srcfolder "$stage" -ov -format UDZO "$dmg" >/dev/null
if [[ $mode == developer-id ]]; then
  codesign --force --timestamp --keychain "$keychain" --sign "$APPLE_SIGNING_IDENTITY" "$dmg"
  xcrun notarytool submit "$dmg" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait
  xcrun stapler staple "$dmg"
  xcrun stapler validate "$dmg"
  spctl --assess --type open --context context:primary-signature "$dmg"
fi
export PINK_NOTARIZATION=$notarization
node scripts/manifest.mjs
(cd dist && shasum -a 256 Pink-*.zip Pink-*.dmg build-info.json > SHA256SUMS)
bash scripts/verify-artifacts.sh
