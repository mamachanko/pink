#!/bin/bash
set -euo pipefail
[[ $(uname -s) == Darwin ]] || { echo 'BLOCKED: macOS and Xcode required' >&2; exit 1; }
: "${PINK_VERSION:=0.0.0}"
: "${PINK_BUILD:=1}"
[[ $PINK_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $PINK_BUILD =~ ^[1-9][0-9]{0,3}(\.[0-9]{1,2}\.[0-9]{1,2})?$ ]] || exit 1
mkdir -p build
.tools/xcodegen generate
xcodebuild -project Pink.xcodeproj -scheme Pink -configuration Release -derivedDataPath build/DerivedData \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- \
  PINK_VERSION="$PINK_VERSION" PINK_BUILD="$PINK_BUILD" PINK_COMMIT="$(git rev-parse HEAD)" build
mkdir -p build/DerivedData/Build/Products/Release/Pink.app/Contents/Resources
swift scripts/icon.swift build/Pink.iconset
iconutil -c icns build/Pink.iconset -o build/DerivedData/Build/Products/Release/Pink.app/Contents/Resources/Pink.icns
cp LICENSE build/DerivedData/Build/Products/Release/Pink.app/Contents/Resources/LICENSE
codesign --force --options runtime --sign - build/DerivedData/Build/Products/Release/Pink.app
