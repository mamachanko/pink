#!/bin/bash
set -euo pipefail
uname -sm
node --version
npm --version
swift --version
if [[ $(uname -s) == Darwin ]]; then
  xcodebuild -version
  xcodebuild -showsdks
  test -x .tools/xcodegen
  .tools/xcodegen --version
else
  echo 'Native build, pasteboard, GUI and packaging: BLOCKED (requires macOS)'
fi
