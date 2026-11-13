# Maintainer setup (review before applying)

Repository identity is mamachanko/pink. CODEOWNERS uses its actual owner @mamachanko; existing MIT copyright Max Brauer is preserved. No new legal identity/contact is inferred. No remote settings were changed.

Review repository Settings:

- Protect main with PR review and required `verify / Required verification` check (confirm exact emitted check name in first real run). Disallow force pushes and deletion, include administrators where appropriate. Add PR title check if desired.
- Enable squash merge. Choose PR title for squash subject and PR body for body so `!` and `BREAKING CHANGE:` reach main. Disable other merge methods if the team adopts this release policy. Review final squash message before merging.
- Actions default token: read-only. Permit only pinned/reviewed actions. Release job explicitly escalates contents:write. Fork workflows must never receive release secrets.
- Create `release` environment restricted to main; optionally require a reviewer and prevent self-review. Default SIGNING_MODE adhoc, or configure complete Developer ID contract in docs/release.md. GitHub environment protections availability depends on plan and repository visibility; don't change visibility to acquire them.
- Protect v* tags from unauthorized creation/update/deletion while allowing the authorized release workflow identity to create them. Check ruleset bypass implications before applying. Never give general write tokens to fork workflows.
- Install/activate Renovate with least repository access. renovate.json alone doesn't activate it. Review pinned Xcode/runner changes and tool checksum updates together; verify official upstream release sources. Configure code scanning or advisory reporting separately if wanted.
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

Reviewable settings template (not automatically executed):

```sh
gh api --method PATCH repos/mamachanko/pink \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY
```

Protection rules need actual emitted check names/app identities; do not submit an invented generic policy. Apply after inspecting the first workflow run. Keep release-environment reviewers, secrets and rules in the GitHub settings UI; never put secret values in issues or repository files.

Renovate custom managers extract the XcodeGen tag plus commit digest from bootstrap, and actionlint/ShellCheck versions from lint-tools. Tool update PRs must include newly verified checksum entries and, for XcodeGen, the genuine upstream Package.resolved. CI deliberately fails an archive update with no matching checksum. Configuration validation does not prove app installation or activation.
