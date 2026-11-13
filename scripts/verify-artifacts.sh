#!/bin/bash
set -euo pipefail
(cd dist && shasum -a 256 -c SHA256SUMS)
node scripts/check-assets.mjs
work=$(mktemp -d)
mount="$work/mount"
cleanup() { hdiutil detach "$mount" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
zip=(dist/RefPaste-*.zip)
dmg=(dist/RefPaste-*.dmg)
ditto -x -k "${zip[0]}" "$work/zip"
hdiutil attach "${dmg[0]}" -mountpoint "$mount" -nobrowse -readonly >/dev/null
for app in "$work/zip/RefPaste.app" "$mount/RefPaste.app"; do
  test -x "$app/Contents/MacOS/RefPaste"
  test -f "$app/Contents/Resources/LICENSE"
  lipo -verify_arch arm64 x86_64 "$app/Contents/MacOS/RefPaste"
  for arch in arm64 x86_64; do
    minos=$(xcrun vtool -arch "$arch" -show-build "$app/Contents/MacOS/RefPaste" | awk '/minos/{print $2}')
    [[ $minos == 15.0 || $minos == 15.0.0 ]]
  done
  codesign --verify --deep --strict --verbose=2 "$app"
  version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
  test "$version" = "$(node -p 'JSON.parse(require("fs").readFileSync("dist/build-info.json")).version')"
  test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")" = "$(node -p 'JSON.parse(require("fs").readFileSync("dist/build-info.json")).build')"
  test "$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$app/Contents/Info.plist")" = 15.0
  test "$(/usr/libexec/PlistBuddy -c 'Print RefPasteCommit' "$app/Contents/Info.plist")" = "$(git rev-parse HEAD)"
  "$app/Contents/MacOS/RefPaste" --smoke-test
 done
