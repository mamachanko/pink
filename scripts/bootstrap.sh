#!/bin/bash
set -euo pipefail
npm ci --ignore-scripts
bash scripts/lint-tools.sh
if [[ $(uname -s) != Darwin ]]; then
  echo 'Release tools ready. Install Swift 6.0+ for portable tests; Xcode required for application builds.'
  exit 0
fi
mkdir -p .tools
# Build pinned source commit; no mutable binary download or unverified archive.
if [[ ! -x .tools/xcodegen ]]; then
  git clone --filter=blob:none https://github.com/yonaskolb/XcodeGen.git .tools/XcodeGen
  git -C .tools/XcodeGen checkout --detach 21ac9944b0ab546a07422dbed86f33dd2ebd76f8
  cp tools/XcodeGen.Package.resolved .tools/XcodeGen/Package.resolved
  (cd .tools/XcodeGen && swift build --force-resolved-versions -c release --product xcodegen)
  cp .tools/XcodeGen/.build/release/xcodegen .tools/xcodegen
fi
