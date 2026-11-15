#!/bin/bash
set -euo pipefail
[[ $(uname -s) == Darwin ]] || { echo 'BLOCKED: macOS and Xcode required' >&2; exit 1; }
: "${PINK_VERSION:=0.0.0}"
: "${PINK_BUILD:=1}"
[[ $PINK_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $PINK_BUILD =~ ^[1-9][0-9]{0,3}(\.[0-9]{1,2}\.[0-9]{1,2})?$ ]] || exit 1
app=build/DerivedData/Build/Products/Release/Pink.app
mkdir -p build
# Recreate only the owned app bundle; retain compiler caches, not stale resources.
rm -rf "$app"
.tools/xcodegen generate
xcodebuild -project Pink.xcodeproj -scheme Pink -configuration Release -derivedDataPath build/DerivedData \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- \
  PINK_VERSION="$PINK_VERSION" PINK_BUILD="$PINK_BUILD" PINK_COMMIT="$(git rev-parse HEAD)" \
  PINK_UPDATE_PUBLIC_KEY="${PINK_UPDATE_PUBLIC_KEY:-}" PINK_UPDATE_MODE="${PINK_UPDATE_MODE:-manual}" build
mkdir -p "$app/Contents/Resources"
swift scripts/icon.swift build/Pink.iconset
iconutil -c icns build/Pink.iconset -o "$app/Contents/Resources/Pink.icns"
cp LICENSE "$app/Contents/Resources/LICENSE"
cp .tools/sparkle/LICENSE "$app/Contents/Resources/Sparkle-LICENSE"
bash scripts/sign-app.sh "$app"
