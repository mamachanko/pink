#!/bin/bash
set -euo pipefail
[[ $(uname -s) == Darwin ]] || { echo 'BLOCKED: macOS and Xcode required' >&2; exit 1; }
: "${REFPASTE_VERSION:=0.0.0}"
: "${REFPASTE_BUILD:=1}"
[[ $REFPASTE_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $REFPASTE_BUILD =~ ^[1-9][0-9]{0,3}(\.[0-9]{1,2}\.[0-9]{1,2})?$ ]] || exit 1
mkdir -p build
.tools/xcodegen generate
xcodebuild -project RefPaste.xcodeproj -scheme RefPaste -configuration Release -derivedDataPath build/DerivedData \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- \
  REFPASTE_VERSION="$REFPASTE_VERSION" REFPASTE_BUILD="$REFPASTE_BUILD" REFPASTE_COMMIT="$(git rev-parse HEAD)" build
mkdir -p build/DerivedData/Build/Products/Release/RefPaste.app/Contents/Resources
swift scripts/icon.swift build/RefPaste.iconset
iconutil -c icns build/RefPaste.iconset -o build/DerivedData/Build/Products/Release/RefPaste.app/Contents/Resources/RefPaste.icns
cp LICENSE build/DerivedData/Build/Products/Release/RefPaste.app/Contents/Resources/LICENSE
codesign --force --options runtime --sign - build/DerivedData/Build/Products/Release/RefPaste.app
