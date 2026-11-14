# Homebrew installation and maintenance

Install from this existing repository; no separate tap or account is required:

```sh
brew tap mamachanko/pink https://github.com/mamachanko/pink.git
brew install --cask mamachanko/pink/pink
brew upgrade --cask mamachanko/pink/pink
```

Use the fully qualified cask name to avoid unrelated packages. Homebrew 6+ grants trust to that cask when installing by its fully qualified name; whole-tap trust is unnecessary. Packages are universal for macOS 15+. The cask pins the final DMG checksum and installs `Pink.app`. It does not launch Pink, enable monitoring, register login items, remove quarantine or change Gatekeeper. Signing caveats follow the actual release's signing/notarization state.

Disable launch at login and quit Pink before uninstalling with `brew uninstall --cask mamachanko/pink/pink`. Add `--zap` only to intentionally remove current and legacy preferences. Native CI audits/styles the cask, installs it into a temporary app directory with isolated cask-specific trust, verifies the bundle, uninstalls and untaps. It never opens the app or modifies system privacy/login permissions.

## One refreshed update PR

The `Homebrew metadata` workflow runs after a push to main, successful main-branch Release completion, or a manual run. A shared concurrency group serializes maintenance without cancelling an active update. Each run reads the latest stable published release at execution time, downloads only its four expected assets, verifies every checksum and tag/manifest commit identity, and generates the cask from the current main-branch template.

One branch, `homebrew/update`, and one open PR are reused. When main advances, a new commit uses main's tree plus the generated cask and retains both previous branch and main parents. The branch update is a regular fast-forward with `force:false`. This keeps the PR current without rewriting history or carrying stale source files. A generated-file digest trailer and comparison against main reject manual/unrelated branch edits; maintainer notes outside the reserved PR-body block are preserved. Newer reviewed cask versions are never downgraded. A main change observed before writing causes a bounded retry with a fresh snapshot; a later race is blocked by strict required checks until the next maintenance run refreshes it.

After the canonical PR is dispatched, recognized older `homebrew/vVERSION` PRs are closed only if bot-authored and their diff changes exactly the cask's version/checksum assignments. Human PRs, edited Ruby, unrelated changes, branches and tags are preserved. This migrates the previous per-release PR flow. The updater never merges a PR or writes directly to main.

## CI without a manual approval step

GitHub documents that `workflow_dispatch` and `repository_dispatch` always start runs when called with `GITHUB_TOKEN`. Token-created `pull_request` events may instead require approval. The updater explicitly dispatches `ci.yml` on the canonical branch with its PR number. The read-only CI validates the exact open, same-repository PR head and Conventional Commit title, then runs all verification and emits `Required checks`. Dispatch and ordinary PR events use separate concurrency groups so an approval-waiting PR event cannot cancel the explicitly dispatched run. Successful or already-running dispatches for that same SHA are reused; failed dispatches remain failures. An approval banner on a separate automatically generated PR-event run does not substitute for the dispatched gate.

No PAT, additional GitHub App, automatic approval or protection bypass is used. The trusted maintenance job needs `contents:write`, `pull-requests:write` and `actions:write`; its dispatched CI remains read-only and has no signing secrets. `workflow_run` accepts only successful Release push runs from this repository's main branch, checks out main, and never executes code or downloads artifacts from the triggering run. Publication keeps its separate release environment and contents write permission.

## Activation and recovery

1. Merge the workflow change so `ci.yml` declares `workflow_dispatch` on the default branch. GitHub requires that default-branch declaration before dispatch is available.
2. Allow GitHub Actions to create pull requests under repository Settings → Actions → General. The repository files cannot activate that setting. Keep default workflow permissions read-only; job-level write scopes are explicit.
3. Run `Homebrew metadata` once if no new main push or successful release has triggered it. Review the single generated PR and merge after `Required checks` succeeds.
4. Apply the main ruleset described in [repository setup](repository-setup.md). New main pushes automatically refresh an outstanding bot PR and dispatch its new head's checks.

If dispatch permission is missing, the job fails visibly after preserving the PR; correct permissions and rerun maintenance. If manual branch edits are detected, review them before resuming rather than force-resetting the branch. A publication followed by maintenance failure remains a published release: rerun maintenance against the verified existing assets, never replace assets or move tags. Live post-merge automation must be observed before claiming activation; local tests mock GitHub mutations and do not create production releases.

Official references consulted 2026-11-14: GitHub Docs [triggering workflows](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow) and [GITHUB_TOKEN event behavior](https://github.com/github/docs/blob/main/data/reusables/actions/actions-do-not-trigger-workflows.md); Homebrew's Cask Cookbook, Tap Trust and tap-maintenance guides. This is a custom tap, not inclusion in homebrew/cask.
