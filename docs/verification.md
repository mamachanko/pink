# Verification record

2026-11-13: Debian 13 x86_64 Linux; Node 24.22.1, npm; Swift 6.2 RELEASE downloaded from official download.swift.org into /tmp/refpaste-swift (outside repository). This ephemeral toolchain is for portable checks only. Native build toolchain pinned in CI is Xcode 26.2.

| Command | Result | Evidence |
|---|---|---|
| repository status/remotes/log/license, uname, tool inspection | PASS | Clean initial work branch, existing MIT; origin mamachanko/pink; Linux; no installed Xcode/Swift |
| initial swift test | FAIL, fixed | Linux XCTest discovery crashed on synchronous MainActor methods; converted to async |
| initial npm test | FAIL, fixed | Latest conventionalcommits preset incompatible with notes writer; pinned 9.1.0; local repository URL corrected |
| swift test after fix | PASS | Core parsing and fake-clock monitor tests |
| npm test | PASS | 14 tests including actual analyzer/notes, semantic-release engine, signing validation and asset corruption |
| make lint | PASS | swift format strict, actionlint 1.7.7, ShellCheck 0.10.0, Bash syntax, YAML/pin policy |
| make bootstrap | See final execution update below | npm integrity lock + checksum verified lint binaries; native tool source build only on macOS |
| make doctor/build/package/verify | See final execution update below | Native commands fail explicitly on Linux |
| macOS proof/native architecture/GUI/receivers | BLOCKED / NOT RUN | No macOS executor available locally |
| signing/notarization/publication | NOT RUN | No Apple credentials or native host; no production release created |

Official documentation research: GitHub actions/runner-images README and both macos-15 inventories successfully consulted; action refs verified with git ls-remote. semantic-release installed documentation/source and official commit-analyzer README consulted; executable tests caught a real dependency incompatibility. Community clipboard marker conventions fetched from nspasteboard/nspasteboard.github.io. Apple's developer.apple.com AppKit documentation and JSON endpoint returned proxy HTTP 403; platform declarations cross-checked using dotnet/macios bindings (not a substitute for current Apple guidance). XcodeGen 2.44.1 pinned source and upstream Package.resolved fetched. ShellCheck archive hashes computed from actual upstream downloads, actionlint hashes from upstream checksum file.

No generated app, ZIP, DMG or screenshots exist from Linux. No native test or compatibility success is inferred from portable tests. Native signing/tool cleanup, version injection and package verification are implemented but await execution. Final checks after implementation are appended below.

Final local execution:

- PASS `make bootstrap doctor` with `/tmp/refpaste-swift/usr/bin` on PATH: npm ci (316 packages), checksum-verified actionlint/ShellCheck, Node 24.22.1/npm 11.9.0/Swift 6.2 on Linux x86_64.
- PASS `make lint test`: 8 portable Swift tests and 14 Node tooling tests. Engine tests execute in isolated child processes because semantic-release's stdout hooks interfere with Node's test-worker protocol. Preparation-failure test uses actual exec plugin, confirms no tag and no publication callback. No tests disabled.
- PASS `git diff --check`.
- BLOCKED `make build`: exits 1, “macOS and Xcode required”. BLOCKED `make package`: exits 1, “macOS packaging required”. `make verify` consequently cannot pass on this host.
- Native AppKit tests, universal build, extracted/mounted artifacts, fixed-version packaging, UI/permissions/login and receiving-app compatibility: NOT RUN. Apple signing/notarization/keychain cleanup: NOT RUN. No distributable artifacts produced.

Remote delivery: git push succeeded using the configured transport. CLI API access was forbidden; the connected GitHub app created draft PR https://github.com/mamachanko/pink/pull/1. CI https://github.com/mamachanko/pink/actions/runs/43385865765 started both macos-15 arm64 and macos-15-intel jobs; title check passed. Native results are recorded below when available.

Additional review: post-write ownership nonce check and external-copy regression test added; portable suite now has 9 tests. Icon rasterization uses an explicit bitmap context so output dimensions don't depend on runner display scale.

Native CI finding (initial run): XcodeGen source built successfully on Darwin arm64, Xcode 26.2/Swift 6.2.3, but doctor failed because case-insensitive macOS volumes conflated `.tools/XcodeGen` and `.tools/xcodegen`. Source checkout moved to `.tools/xcodegen-source`; fresh CI run validates the fix. This was an implementation failure, not an access blocker.

Dependency review: npm audit reported a YAML stack-exhaustion advisory; direct YAML tooling dependency updated to verified 2.9.1. It also reports a minimatch advisory propagated through semantic-release's installed but unused @semantic-release/npm/npm dependency tree. The configured plugin list never invokes npm publication. No untested major override or semantic-release downgrade was applied. This residual build-tool advisory requires upstream maintenance review; no Node dependencies ship in the app.
