#!/bin/bash
set -euo pipefail
actionlint_version=1.7.7 # renovate: depName=rhysd/actionlint
shellcheck_version=0.10.0 # renovate: depName=koalaman/shellcheck
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case $arch in
  x86_64) action_arch=amd64; shell_arch=x86_64 ;;
  arm64|aarch64) action_arch=arm64; shell_arch=aarch64 ;;
  *) echo 'Unsupported lint tool architecture' >&2; exit 1 ;;
esac
mkdir -p .tools
archive="actionlint_${actionlint_version}_${os}_${action_arch}.tar.gz"
if [[ ! -x .tools/actionlint ]]; then
  curl -fsSL "https://github.com/rhysd/actionlint/releases/download/v${actionlint_version}/$archive" -o ".tools/$archive"
  (cd .tools && shasum -a 256 -c <(grep "  $archive$" ../tools/actionlint-checksums.txt))
  tar -xzf ".tools/$archive" -C .tools actionlint
fi
archive="shellcheck-v${shellcheck_version}.$os.$shell_arch.tar.xz"
if [[ ! -x .tools/shellcheck ]]; then
  curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/v${shellcheck_version}/$archive" -o ".tools/$archive"
  (cd .tools && shasum -a 256 -c <(grep "  $archive$" ../tools/shellcheck-checksums.txt))
  tar -xJf ".tools/$archive" -C .tools
  cp .tools/shellcheck-v${shellcheck_version}/shellcheck .tools/shellcheck
fi
