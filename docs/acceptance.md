# Acceptance ledger

Status applies to the delivered implementation, not intended behavior. See verification.md for actual commands.

| Criterion | Status | Evidence / remaining work |
|---|---|---|
| Pure parsing, validation and exact original preservation | PASS | Portable Swift tests |
| Injected state machine, self-write/restoration/race behavior | PASS | Portable fake-clock tests; coverage is bounded to observable checkpoints |
| Semantic-release version rules including breaking docs/chore | PASS | Installed plugins and temporary Git repositories |
| Formatting, action pin policy, YAML/shell validation | PASS | make lint on Linux |
| Native one-item HTML/plain/RTF mechanism | PASS (arm64 + Intel CI) | Three named AppKit tests passed natively on both architectures with exact plain text and RTF destination |
| Full app build/universal package | PASS | Both macOS CI jobs passed universal build, ZIP/DMG verification and smoke tests |
| Native UI accessibility/light/dark/keyboard | NOT RUN | Requires actual macOS interaction |
| OS clipboard permission / SMAppService behavior | NOT RUN | Guarded APIs implemented; needs OS verification |
| Receiver compatibility | NOT RUN | All rows in compatibility.md |
| Temporary signing cleanup on invalid certificate | PASS | Both native CI jobs exercised real temporary keychain creation/import failure/cleanup |
| Developer ID signing/notarization | BLOCKED | No real Apple credentials; no production release authorized |
| Published release integrity / recovery | NOT RUN | Workflow implemented; no production test release |
| Branch/PR/native CI | PASS | Pushed feat/refpaste; draft PR #1; reusable verification passed on both architectures |
| Repository protection/environment/Renovate activation | NOT RUN | Maintainer setup only; no settings silently changed |

Conservative implementation restrictions: existing HTML clipboard content is skipped rather than imported; ambiguous encoded separators aren't supported. Native tests cover the adapter and full monitor restoration but not every AppKit failure mode. Manual application and permission acceptance remains outstanding. These are unmet verification criteria, not passing claims.
