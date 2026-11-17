# Maintainer setup (review before applying)

Optional signed in-app update delivery requires release-environment `PINK_UPDATE_MODE=sparkle`, public-key variable and private-key secret as documented in [updates.md](updates.md). These are not activated by repository files or test keys. Existing Apple signing configuration remains separate.

Repository identity is mamachanko/pink. CODEOWNERS uses its actual owner @mamachanko; existing MIT copyright Max Brauer is preserved. No new legal identity/contact is inferred. No remote settings were changed.

Review repository Settings:

- Apply `.github/rulesets/main.json` after the workflow changes have passed on main. It requires a PR, the unique `Required checks` gate from the observed GitHub Actions integration (15368), an up-to-date base, resolved review threads, squash/rebase merging and linear history; it blocks deletion/force pushes and provides no admin bypass. Required approving reviews is zero for this single-owner repository so the owner can merge their own checked PRs. Add a second-person approval requirement when another reviewer is available.
- If the squash-plus-rebase option is selected, enable squash without disabling the existing rebase method. Choose PR title for squash subject and PR body for body so `!` and `BREAKING CHANGE:` reach main. Source commit subjects are also validated for rebase merges. Review the final merge message.
- Actions default token: read-only. Permit only pinned/reviewed actions. Release publishing explicitly escalates contents:write. Trusted Homebrew maintenance separately uses contents/pull-requests/actions write scopes; dispatched CI remains read-only. Fork workflows must never receive release secrets.
- Create `release` environment restricted to main; optionally require a reviewer and prevent self-review. Default SIGNING_MODE adhoc, or configure complete Developer ID contract in docs/release.md. GitHub environment protections availability depends on plan and repository visibility; don't change visibility to acquire them.
- Protect v* tags from unauthorized creation/update/deletion while allowing the authorized release workflow identity to create them. Check ruleset bypass implications before applying. Never give general write tokens to fork workflows.
- Configure the nightly Renovate Action as described below. renovate.json alone does not activate it. Review pinned Xcode/runner changes and tool checksum updates together; verify official upstream release sources. Configure code scanning or advisory reporting separately if wanted.
- Enable private vulnerability reporting under Security if supported; SECURITY.md does not activate it.
- Ensure Actions macos-15 arm64 and macos-15-intel runners are available within account quota. Large/xlarge labels aren't silently substituted because they may incur costs.

Read-only audit commands:

```sh
gh api repos/mamachanko/pink
gh api repos/mamachanko/pink/actions/permissions
gh api repos/mamachanko/pink/branches/main/protection
gh api repos/mamachanko/pink/rulesets
gh api repos/mamachanko/pink/environments
```

Optional squash-plus-rebase settings template (not executed; apply only after choosing that merge-method option):

```sh
gh api --method PATCH repos/mamachanko/pink \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=true \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY
```

Protection rules need actual emitted check names/app identities; do not submit an invented generic policy. Apply after inspecting the first workflow run. Keep release-environment reviewers, secrets and rules in the GitHub settings UI; never put secret values in issues or repository files.

Renovate custom managers extract the XcodeGen tag plus commit digest from bootstrap, and actionlint/ShellCheck versions from lint-tools. Tool update PRs must include newly verified checksum entries and, for XcodeGen, the genuine upstream Package.resolved. CI deliberately fails an archive update with no matching checksum. Configuration validation does not prove app installation or activation.

## Merge-method compatibility

The live repository currently enables rebase merges and disables squash/merge commits. The ruleset permits squash and rebase but does not itself enable a repository merge method. Source commit subjects are validated alongside PR titles so rebase merging preserves release signals.

The proposed single-PR, non-forced Homebrew refresh retains merge ancestry. Squash merging is recommended for that automation PR when main has advanced. Enabling squash while retaining rebase is a separate administrator setting; no live merge-method setting has been changed. Confirm that preference before activating the new Homebrew flow. Keep the new PR in draft if rebase-only operation is desired until that alternative is selected and tested.

## Apply and verify the main ruleset

Audit on 2026-11-14: the repository API returned no rulesets and `main.protected:false`. The connected GitHub tools do not expose administration writes, the workspace CLI API was denied, and the desktop failed to start. **The ruleset is prepared, not applied.** A JSON file is not evidence of live protection.

After this change is merged and main has a passing `Required checks` run, use a GitHub CLI authenticated with repository administration write access:

```sh
node scripts/apply-ruleset.mjs          # inspect the validated policy; no writes
node scripts/apply-ruleset.mjs --apply  # create, then read back every requested protection
```

Alternatively import `.github/rulesets/main.json` in Settings → Rules → Rulesets. The helper requires an observed successful `Required checks` run on main before activation, avoids overwriting a different existing ruleset, and verifies the complete policy after creation. It never changes visibility, tag rules, secrets or existing protection policies. Read the resulting ruleset and confirm enforcement is active; do not bypass a missing check to finish setup.

## Which checks must pass?

The unique `Required checks` job is the merge requirement. It rejects failures, cancellations, missing results and unexpected skips. It covers:

- `verify / Required verification`: both native architectures, lint, unit/integration/release-tooling tests, universal packaging/signature/checksum/smoke checks, Homebrew checks, and the reusable native README capture workflow.
- PR-title and source-commit validation, including title edits and exact-head validation for a manually dispatched automation PR.

The screenshot workflow is now reusable and runs within verification for every PR and release, so path-filtered jobs cannot silently escape the gate. Release publication and Homebrew maintenance are post-merge workflows, not PR checks; requiring those names would block PRs permanently. Release publication still waits for full reusable verification of its exact commit.

Homebrew uses one refreshed PR and explicit CI dispatch with GITHUB_TOKEN, without a PAT or extra App. See [Homebrew maintenance](homebrew.md) for activation, permission boundaries, strict-base refresh, safe legacy PR retirement and recovery. All action implementations remain pinned Node 24 actions; hosted runner versions are printed by CI.

## Nightly Renovate

[Renovate](../.github/workflows/renovate.yml) runs nightly at **02:17 UTC** and supports **Actions → Renovate → Run workflow**. GitHub schedules run from the default branch and may be delayed; merge the workflow to `main` before expecting scheduled runs or the manual trigger. Logs are available in each Actions run. The job targets only `mamachanko/pink`, reads the existing `renovate.json` from the repository, and skips the onboarding PR. The recommended preset enables the Dependency Dashboard issue. Action code and the Renovate container version are pinned; Renovate proposes updates to both.

Before the first run:

1. Create a fine-grained personal access token restricted to `mamachanko/pink`, with **Contents**, **Issues**, **Pull requests**, and **Workflows** set to **Read and write** (Metadata read access is automatic). Store it as the repository Actions secret **`RENOVATE_TOKEN`** under Settings → Secrets and variables → Actions. Choose an expiry and rotate the secret before it expires. Alternatively, a classic token for this public repository needs `public_repo` and `workflow` scopes.
2. Remove `pink` from the hosted Renovate GitHub App's repository access, or uninstall that app if it serves no other repositories. Run only one Renovate service against the repository to avoid competing updates.
3. Ensure repository Issues and GitHub Actions are enabled and the action policy permits `renovatebot/github-action`. Run the workflow manually after merging, inspect its logs, and confirm the Dependency Dashboard appears. No update PRs are expected when all detected dependencies are current.

The job's built-in `GITHUB_TOKEN` stays read-only. The separate token lets Renovate update `.github/workflows` and lets its PRs trigger normal CI. A missing secret fails with a setup message. The token cannot be provisioned by committing workflow files; the hosted app installation does not supply this secret. Review pinned Xcode/runner changes and tool checksum updates together; CI still requires matching verified tool checksums.
