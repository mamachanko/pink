#!/bin/bash
set -euo pipefail
app=$1
identity=${2:--}
keychain=${3:-}
args=(--force --options runtime --sign "$identity")
if [[ $identity != - ]]; then
  args+=(--timestamp)
  if [[ -n $keychain ]]; then args+=(--keychain "$keychain"); fi
fi
framework="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
# Sign inside out; never use --deep to sign or apply app entitlements to helpers.
codesign "${args[@]}" --preserve-metadata=entitlements "$framework/Autoupdate"
while IFS= read -r -d '' nested; do
  codesign "${args[@]}" --preserve-metadata=entitlements "$nested"
done < <(find "$framework" -depth \( -name '*.xpc' -o -name '*.app' \) -type d -print0)
codesign "${args[@]}" "$app/Contents/Frameworks/Sparkle.framework"
if [[ $identity == - ]]; then
  codesign "${args[@]}" --entitlements App/Adhoc.entitlements "$app"
else
  codesign "${args[@]}" "$app"
fi
codesign --verify --deep --strict "$app"
