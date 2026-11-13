#!/bin/bash
set -euo pipefail
(cd dist && shasum -a 256 -c SHA256SUMS)
node scripts/check-assets.mjs
work=$(mktemp -d)
mount="$work/mount"
cleanup() { hdiutil detach "$mount" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
zip=(dist/Pink-*.zip)
dmg=(dist/Pink-*.dmg)
ditto -x -k "${zip[0]}" "$work/zip"
hdiutil attach "${dmg[0]}" -mountpoint "$mount" -nobrowse -readonly >/dev/null
test -L "$mount/Applications"
test "$(readlink "$mount/Applications")" = /Applications
for app in "$work/zip/Pink.app" "$mount/Pink.app"; do
  test -x "$app/Contents/MacOS/Pink"
  test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" = io.github.mamachanko.pink
  test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleName' "$app/Contents/Info.plist")" = Pink
  test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleDisplayName' "$app/Contents/Info.plist")" = Pink
  test -f "$app/Contents/Resources/LICENSE"
  test -s "$app/Contents/Resources/Pink.icns"
  lipo "$app/Contents/MacOS/Pink" -verify_arch arm64 x86_64
  for arch in arm64 x86_64; do
    minos=$(xcrun vtool -arch "$arch" -show-build "$app/Contents/MacOS/Pink" | awk '/minos/{print $2}')
    [[ $minos == 15.0 || $minos == 15.0.0 ]]
  done
  codesign --verify --deep --strict --verbose=2 "$app"
  version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
  test "$version" = "$(node -p 'JSON.parse(require("fs").readFileSync("dist/build-info.json")).version')"
  test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")" = "$(node -p 'JSON.parse(require("fs").readFileSync("dist/build-info.json")).build')"
  test "$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$app/Contents/Info.plist")" = 15.0
  test "$(/usr/libexec/PlistBuddy -c 'Print PinkCommit' "$app/Contents/Info.plist")" = "$(git rev-parse HEAD)"
  node -e 'const r=require("node:child_process").spawnSync(process.argv[1],["--smoke-test"],{timeout:15000,stdio:"inherit"}); if(r.error || r.status!==0) process.exit(1)' "$app/Contents/MacOS/Pink"
 done
