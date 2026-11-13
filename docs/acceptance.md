# Acceptance ledger

Status applies to the delivered implementation, not intended behavior. See verification.md for actual commands.

| Criterion | Status | Evidence / remaining work |
|---|---|---|
| Pure parsing, validation and exact original preservation | PASS | Portable Swift tests |
| Injected state machine, self-write/restoration/race behavior | PASS | Portable fake-clock tests; coverage is bounded to observable checkpoints |
| Semantic-release version rules including breaking docs/chore | PASS | Installed plugins and temporary Git repositories |
| Formatting, action pin policy, YAML/shell validation | PASS | make lint on Linux |
| Native one-item HTML/plain/RTF mechanism | NOT RUN | Named AppKit proof test implemented; needs macOS |
| Full app build/universal package | BLOCKED | Linux cannot execute Xcode/AppKit/hdiutil |
| Native UI accessibility/light/dark/keyboard | NOT RUN | Requires actual macOS interaction |
| OS clipboard permission / SMAppService behavior | NOT RUN | Guarded APIs implemented; needs OS verification |
| Receiver compatibility | NOT RUN | All rows in compatibility.md |
| Developer ID/notarization/cleanup on macOS failures | BLOCKED | No macOS or Apple credentials |
| Published release integrity / recovery | NOT RUN | Workflow implemented; no production test release |
| Branch/PR/native CI | See verification.md | Remote delivery attempted after commit |
| Repository protection/environment/Renovate activation | NOT RUN | Maintainer setup only; no settings silently changed |

Conservative implementation restrictions: existing HTML clipboard content is skipped rather than imported; encoded/Unicode path segments aren't supported. Native tests don't yet cover every platform read failure/marker/serialization variant. A macOS build failure remains possible until real CI runs. These are unmet verification criteria, not passing claims.
