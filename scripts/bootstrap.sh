#!/bin/bash
set -euo pipefail
npm ci --ignore-scripts
bash scripts/lint-tools.sh
if [[ $(uname -s) != Darwin ]]; then
  echo 'Release tools ready. Install Swift 6.0+ for portable tests; Xcode required for application builds.'
  exit 0
fi
mkdir -p .tools
node scripts/bootstrap-sparkle.mjs
# Build pinned source commit; no mutable binary download or unverified archive.
if [[ ! -x .tools/xcodegen ]]; then
  git clone --filter=blob:none https://github.com/yonaskolb/XcodeGen.git .tools/xcodegen-source
  # renovate: depName=yonaskolb/XcodeGen version=2.49.0
  git -C .tools/xcodegen-source checkout --detach 45ad520d50c26f42b0f4e823e8dd5e18e3ae27c9
  cp tools/XcodeGen.Package.resolved .tools/xcodegen-source/Package.resolved
  (cd .tools/xcodegen-source && swift build --force-resolved-versions -c release --product xcodegen)
  cp .tools/xcodegen-source/.build/release/xcodegen .tools/xcodegen
fi
