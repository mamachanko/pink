#!/bin/bash
set -euo pipefail
app=$1
version=$2
commit=$3
test -x "$app/Contents/MacOS/Pink"
for field in CFBundleName CFBundleDisplayName CFBundleExecutable; do
  test "$(/usr/libexec/PlistBuddy -c "Print $field" "$app/Contents/Info.plist")" = Pink
done
test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" = io.github.mamachanko.pink
test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" = "$version"
test "$(/usr/libexec/PlistBuddy -c 'Print PinkCommit' "$app/Contents/Info.plist")" = "$commit"
test "$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$app/Contents/Info.plist")" = 15.0
test -f "$app/Contents/Resources/LICENSE"
test -s "$app/Contents/Resources/Pink.icns"
lipo "$app/Contents/MacOS/Pink" -verify_arch arm64 x86_64
for arch in arm64 x86_64; do
  minos=$(xcrun vtool -arch "$arch" -show-build "$app/Contents/MacOS/Pink" | awk '/minos/{print $2}')
  [[ $minos == 15.0 || $minos == 15.0.0 ]]
done
codesign --verify --deep --strict --verbose=2 "$app"
while IFS= read -r -d '' strings; do
  for field in CFBundleName CFBundleDisplayName; do
    value=$(/usr/libexec/PlistBuddy -c "Print $field" "$strings" 2>/dev/null || true)
    [[ -z $value || $value == Pink ]]
  done
done < <(find "$app/Contents/Resources" -name InfoPlist.strings -print0)
