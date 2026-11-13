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
node scripts/mount-image.mjs "${dmg[0]}" "$mount"
diskutil info -plist "$mount" > "$work/volume.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print VolumeName' "$work/volume.plist")" = Pink
test -L "$mount/Applications"
test "$(readlink "$mount/Applications")" = /Applications
version=$(node -p 'JSON.parse(require("fs").readFileSync("dist/build-info.json")).version')
for root in "$work/zip" "$mount"; do
  node scripts/package-layout.mjs "$root"
  app="$root/Pink.app"
  bash scripts/verify-bundle.sh "$app" "$version" "$(git rev-parse HEAD)"
  test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")" = "$(node -p 'JSON.parse(require("fs").readFileSync("dist/build-info.json")).build')"
  node -e 'const r=require("node:child_process").spawnSync(process.argv[1],["--smoke-test"],{timeout:15000,stdio:"inherit"}); if(r.error || r.status!==0) process.exit(1)' "$app/Contents/MacOS/Pink"
done
echo 'PASS: ZIP and mounted Pink volume contain exactly Pink.app with Pink metadata and executable'
