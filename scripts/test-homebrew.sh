#!/bin/bash
set -euo pipefail
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_INSTALL_CLEANUP=1
brew --version
if brew tap | grep -q '^mamachanko/pink$'; then
  echo 'Refusing to change an existing Pink tap during verification' >&2
  exit 1
fi
work=$(mktemp -d)
tapped=false
cleanup() {
  if [[ $tapped == true ]]; then
    if brew list --cask mamachanko/pink/pink >/dev/null 2>&1; then
      brew uninstall --cask --appdir="$work/Applications" mamachanko/pink/pink
    fi
    brew untap mamachanko/pink
  fi
  rm -rf "$work"
}
trap cleanup EXIT
brew tap mamachanko/pink "$PWD"
tapped=true
brew style Casks/pink.rb
brew audit --cask mamachanko/pink/pink
brew install --cask --appdir="$work/Applications" mamachanko/pink/pink
node scripts/package-layout.mjs "$work/Applications"
version=$(sed -n 's/^  version "\(.*\)"/\1/p' Casks/pink.rb)
# The pinned bootstrap cask is the actual, checksum-verified public release.
if [[ $version == 1.0.2 ]]; then
  bash scripts/verify-bundle.sh "$work/Applications/Pink.app" "$version" 2c98715cc76683c9bb916d30689130bc2775bf46
fi
echo 'PASS: Homebrew installed Pink.app into the isolated test app directory'
