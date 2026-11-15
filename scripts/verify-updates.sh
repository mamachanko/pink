#!/bin/bash
set -euo pipefail
app=$1
manifest=$2
mode=$(node -p 'JSON.parse(require("fs").readFileSync(process.argv[1])).updates.mode' "$manifest")
public_key=$(node -p 'JSON.parse(require("fs").readFileSync(process.argv[1])).updates.publicKey || ""' "$manifest")
signing=$(node -p 'JSON.parse(require("fs").readFileSync(process.argv[1])).signingMode' "$manifest")
plist="$app/Contents/Info.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print PinkUpdateMode' "$plist")" = "$mode"
test "$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' "$plist")" = "$public_key"
test "$(/usr/libexec/PlistBuddy -c 'Print SUFeedURL' "$plist")" = https://github.com/mamachanko/pink/releases/latest/download/appcast.xml
test "$(/usr/libexec/PlistBuddy -c 'Print SUSignedFeedFailureExpirationInterval' "$plist")" = 0
for flag in SUEnableAutomaticChecks SUAutomaticallyUpdate SUAllowsAutomaticUpdates SUEnableSystemProfiling SUShowReleaseNotes; do
  test "$(/usr/libexec/PlistBuddy -c "Print $flag" "$plist")" = false
done
for flag in SUVerifyUpdateBeforeExtraction SURequireSignedFeed; do
  test "$(/usr/libexec/PlistBuddy -c "Print $flag" "$plist")" = true
done
test -s "$app/Contents/Resources/Sparkle-LICENSE"
framework="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$framework/Resources/Info.plist")" = "$(node -p 'JSON.parse(require("fs").readFileSync("tools/sparkle.json")).version')"
for binary in Sparkle Autoupdate Updater.app/Contents/MacOS/Updater XPCServices/Downloader.xpc/Contents/MacOS/Downloader XPCServices/Installer.xpc/Contents/MacOS/Installer; do
  test -x "$framework/$binary"
  lipo "$framework/$binary" -verify_arch arm64 x86_64
done
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
for helper in Autoupdate Updater.app XPCServices/Downloader.xpc XPCServices/Installer.xpc; do
  codesign -d --entitlements :- ".tools/sparkle/Sparkle.framework/Versions/B/$helper" > "$work/vendor.plist" 2>/dev/null
  codesign -d --entitlements :- "$framework/$helper" > "$work/bundled.plist" 2>/dev/null
  for side in vendor bundled; do
    if [[ -s "$work/$side.plist" ]]; then
      plutil -convert json -o "$work/$side.json" "$work/$side.plist"
    else
      printf '{}\n' > "$work/$side.json"
    fi
  done
  node -e 'const fs=require("node:fs"); require("node:assert/strict").deepEqual(JSON.parse(fs.readFileSync(process.argv[1])),JSON.parse(fs.readFileSync(process.argv[2])))' "$work/vendor.json" "$work/bundled.json"
done
codesign -d --entitlements :- "$app" > "$work/entitlements.plist" 2>/dev/null
exception=$(/usr/libexec/PlistBuddy -c 'Print com.apple.security.cs.disable-library-validation' "$work/entitlements.plist" 2>/dev/null || true)
if [[ $signing == adhoc ]]; then
  test "$exception" = true
else
  test -z "$exception"
fi
echo 'PASS: universal updater helpers, feed/key configuration, privacy defaults and signing-mode entitlements'
