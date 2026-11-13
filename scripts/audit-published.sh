#!/bin/bash
set -euo pipefail
work=$(mktemp -d)
mount="$work/mount"
cleanup() { hdiutil detach "$mount" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT
while read -r version checksum commit; do
  curl --fail --location --silent --show-error "https://github.com/mamachanko/pink/releases/download/v$version/Pink-$version-adhoc.dmg" -o "$work/Pink-$version.dmg"
  printf '%s  %s\n' "$checksum" "$work/Pink-$version.dmg" | shasum -a 256 -c -
  node scripts/mount-image.mjs "$work/Pink-$version.dmg" "$mount"
  diskutil info -plist "$mount" > "$work/volume.plist"
  test "$(/usr/libexec/PlistBuddy -c 'Print VolumeName' "$work/volume.plist")" = Pink
  node scripts/package-layout.mjs "$mount"
  bash scripts/verify-bundle.sh "$mount/Pink.app" "$version" "$commit"
  echo "PASS: published v$version DMG volume, app, executable and bundle identity are Pink"
  hdiutil detach "$mount" >/dev/null
done <<'RELEASES'
1.0.1 8b052d04972753a84b6a20f14eb5dbbedd9c58d44788a032fc5f9190b404419d 0f5d6cb1a654bd6ee711e1aed0aec76ac596314d
1.0.2 605a7bf702ea7039a02f9fceab39f79b4c81b85a838f602f27866015bbe8c521 2c98715cc76683c9bb916d30689130bc2775bf46
RELEASES
