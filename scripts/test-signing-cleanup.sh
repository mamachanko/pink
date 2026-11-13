#!/bin/bash
set -euo pipefail
[[ $(uname -s) == Darwin ]] || { echo 'BLOCKED: macOS keychain test required' >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/keys"
# Deliberately invalid certificate: no real Apple credentials or network request.
if REFPASTE_TEMP_ROOT="$work/keys" SIGNING_MODE=developer-id \
  APPLE_CERTIFICATE_P12_BASE64=bm90LWEtY2VydGlmaWNhdGU= \
  APPLE_CERTIFICATE_PASSWORD=synthetic APPLE_SIGNING_IDENTITY=synthetic \
  APPLE_ID=test@example.invalid APPLE_TEAM_ID=synthetic APPLE_APP_PASSWORD=synthetic \
  bash scripts/package.sh > "$work/result.log" 2>&1; then
  echo 'Invalid certificate unexpectedly accepted' >&2
  exit 1
fi
grep -q signing-keychain-created "$work/result.log"
# Require failure at import, not an unrelated earlier build error.
grep -q 'security: SecKeychainItemImport' "$work/result.log"
[[ -z $(ls -A "$work/keys") ]]
echo 'PASS: invalid certificate failed; temporary signing keychain and certificate cleaned up'
