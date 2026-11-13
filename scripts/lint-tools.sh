#!/bin/bash
set -euo pipefail
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case $arch in
  x86_64) action_arch=amd64; shell_arch=x86_64 ;;
  arm64|aarch64) action_arch=arm64; shell_arch=aarch64 ;;
  *) echo 'Unsupported lint tool architecture' >&2; exit 1 ;;
esac
mkdir -p .tools
archive="actionlint_1.7.7_${os}_${action_arch}.tar.gz"
if [[ ! -x .tools/actionlint ]]; then
  curl -fsSL "https://github.com/rhysd/actionlint/releases/download/v1.7.7/$archive" -o ".tools/$archive"
  (cd .tools && shasum -a 256 -c <(grep "  $archive$" ../tools/actionlint-checksums.txt))
  tar -xzf ".tools/$archive" -C .tools actionlint
fi
archive="shellcheck-v0.10.0.$os.$shell_arch.tar.xz"
if [[ ! -x .tools/shellcheck ]]; then
  curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/v0.10.0/$archive" -o ".tools/$archive"
  (cd .tools && shasum -a 256 -c <(grep "  $archive$" ../tools/shellcheck-checksums.txt))
  tar -xJf ".tools/$archive" -C .tools
  cp .tools/shellcheck-v0.10.0/shellcheck .tools/shellcheck
fi
