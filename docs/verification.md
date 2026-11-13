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

Native evidence update: run 43386214786, macos-15 arm64, Xcode 26.2 (17C52), Swift 6.2.3, passed strict lint, 12 Swift tests (9 core + 3 named AppKit), and release-tool tests. Native one-item plain/HTML/RTF representation, RTF label/target round trip, existing rich-link rejection and custom-type rejection are now PASS on that runner. App compilation then failed on SwiftUI/Core `Settings` ambiguity; references were qualified and PRODUCT_BUNDLE_IDENTIFIER supplied. A follow-up selector-renaming mistake was caught by lint and corrected; final local lint/test passes. Latest native workflow must still finish on the corrected commit. GUI/receiver compatibility remains NOT RUN.

Intel evidence: run 43386214786 job 131755213986 printed Darwin x86_64 / x86_64-apple-macosx15.0 and passed the same 12 native Swift tests (including 3 named AppKit tests). App build hit the same Settings ambiguity, now fixed. Thus native representation proof and core execution have real coverage on both architectures; universal app/package success is still separate.

Corrected app-build evidence: run 43386950833 Apple Silicon job completed universal Xcode application compilation (BUILD SUCCEEDED), generated icon, ad-hoc signed app, ZIP, DMG and checksums. Artifact verification then failed because lipo treated a trailing input filename as an architecture. The input is now placed before `-verify_arch`. No failed package is presented as verified. A pinned actions/cache cache stores only tool builds by OS/architecture/Xcode/tool-lock digest to shorten reruns.

## Completed native verification

PASS on both macos-15 arm64 and macos-15-intel x86_64 in https://github.com/mamachanko/pink/actions/runs/43388584128 (source 6b2117f77ddb772d2b59b610c9e9b54f8df4fd6b), required aggregate success:

- `make bootstrap doctor verify`: strict lint; 13 Swift tests (9 core + 4 named AppKit, including monitor ownership/restoration); 14 release-tool tests; universal application build and ad-hoc package verification.
- `bash scripts/test-signing-cleanup.sh`: real temporary keychain created, synthetic invalid certificate rejected at import, temporary keychain/certificate directory removed. No real Apple credentials, notarization request or production release.
- `node scripts/prepare.mjs 1.2.3`: fixed-version build injection, ZIP and drag-install DMG, final checksums and build-info.json; both extracted/mounted apps passed architecture, minimum OS, marketing/build/commit metadata, signature and safe launch/exit checks.
- Both jobs uploaded separate RefPaste-macos-15 / RefPaste-macos-15-intel artifact bundles containing the four explicit release assets. Ad-hoc signed; not Developer ID signed; not notarized. These are CI test packages, not a published release.

The native integration test initially exposed ownership failure after reading back a generated rich item. A dedicated marker-only read fixed it; the full integration test now passes. Later revision also pauses polling before sleep/session inactivity and strengthens cleanup search-list comparison; final revision CI is checked separately. No native test changes the general clipboard, system permissions or launch-at-login registration.

Earlier NOT RUN/BLOCKED rows above describe the initial Linux stage and are superseded by this native evidence for automated checks. Receiving apps, interactive UI/VoiceOver/appearance, actual clipboard privacy policy changes, login approval, successful Developer ID signing/notarization and publication/recovery remain NOT RUN. Protection/environment/Renovate activation remains maintainer setup.

## Pink 💕 naming follow-up

Product identity is now Pink throughout UI, Swift targets/modules, XcodeGen, bundle/executable/icon, CI artifacts, release assets, build variables and current documentation. The 💕 emoji replaces the menu-bar link symbol and application icon glyph. Earlier records above retain original names and paths as historical evidence.

Local PASS: `make lint test` with Swift 6.2 on Linux (12 core tests, including two settings-migration tests; 14 installed release-tooling tests). `npm install --package-lock-only --ignore-scripts` regenerated the package-name metadata with no dependency-version changes. `git diff --check` passed. Native bundle metadata checks now require Pink, its new bundle ID and Pink executable/icon paths; native compilation, icon generation and packaging are verified by follow-up CI, not inferred from Linux results. Preference migration imports validated settings only, never overrides existing Pink preferences, and never changes clipboard permissions or login registration.

## Distribution, action-runtime and Homebrew follow-up

Read-only release investigation retrieved real v1.0.0/v1.0.1/v1.0.2 metadata. v1.0.0 retains historical RefPaste asset names. The actual v1.0.2 ZIP was downloaded: SHA-256 adcbe7f51f8d97206b9963afb8b640f3aa263bc8b2a16c0bc4feb78356005f94; sole top-level bundle Pink.app; name/display/executable Pink; identifier io.github.mamachanko.pink; version 1.0.2. The actual DMG was downloaded and its digest matches 605a7bf702ea7039a02f9fceab39f79b4c81b85a838f602f27866015bbe8c521. Linux cannot mount it; independent read-only audits of both published renamed DMGs are delegated to macOS CI, without replacing any release.

Official action tags/full SHAs and action.yml files were fetched: all four replacement actions declare node24. Official Homebrew cask/tap/manpage documentation was consulted. Local lint and portable/tooling tests pass; new tests reject legacy/additional/linked app bundles and stale executables, validate cask checksums/signing claims, and exercise cask-update PR creation/API-failure cleanup without network or writes to main. Native DMG audits and real Homebrew installation checks are reported by the follow-up PR/CI; no success is inferred from Linux.

Native follow-up evidence: run https://github.com/mamachanko/pink/actions/runs/43408439109 (Apple Silicon job 131828498639) passed 17 Swift tests, 18 release-tooling tests, universal ZIP/DMG verification, failed-certificate cleanup and the read-only mounted v1.0.1/v1.0.2 audits. Homebrew 7.0.12 style/audit/download/install and installed Pink.app identity/signature checks passed. The overall job failed in test cleanup because uninstall does not accept --appdir. Cleanup now uses Homebrew's saved installation location, checks removal and attempts untapping even after an error; final rerun results are recorded on PR #4. README capture passed with the updated Node 24 actions; the completed job has no Node 20 deprecation warning. Developer ID signing/notarization and receiving-app compatibility were not exercised by this follow-up.
