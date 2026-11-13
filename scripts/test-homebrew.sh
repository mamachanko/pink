#!/bin/bash
set -euo pipefail
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_DEVELOPER=1
brew --version
if brew tap | grep -q '^mamachanko/pink$'; then
  echo 'Refusing to change an existing Pink tap during verification' >&2
  exit 1
fi
work=$(mktemp -d)
# Homebrew 6+ records item trust here; keep verification trust out of user settings.
export XDG_CONFIG_HOME="$work/config"
tapped=false
cleanup() {
  local result=$?
  if [[ $tapped == true ]]; then
    if brew list --cask mamachanko/pink/pink >/dev/null 2>&1; then
      # Homebrew remembers the app directory in installed cask metadata.
      brew uninstall --cask mamachanko/pink/pink || result=1
    fi
    if [[ -e "$work/Applications/Pink.app" ]]; then
      echo 'Homebrew did not remove the temporary application' >&2
      result=1
    fi
    brew untap mamachanko/pink || result=1
  fi
  rm -rf "$work"
  if [[ $result == 0 ]]; then echo 'PASS: Homebrew uninstalled Pink and removed the temporary tap/configuration'; fi
  return "$result"
}
trap cleanup EXIT
brew tap mamachanko/pink "$PWD"
tapped=true
brew style Casks/pink.rb
brew trust --cask mamachanko/pink/pink
brew audit --cask mamachanko/pink/pink
brew install --cask --appdir="$work/Applications" mamachanko/pink/pink
node scripts/package-layout.mjs "$work/Applications"
version=$(sed -n 's/^  version "\(.*\)"/\1/p' Casks/pink.rb)
# The pinned bootstrap cask is the actual, checksum-verified public release.
if [[ $version == 1.0.2 ]]; then
  bash scripts/verify-bundle.sh "$work/Applications/Pink.app" "$version" 2c98715cc76683c9bb916d30689130bc2775bf46
fi
echo 'PASS: Homebrew installed Pink.app into the isolated test app directory'
