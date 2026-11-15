# Updates

Choose **Settings → Check for Updates…**, or the same action in the Pink menu. There are no background checks, silent downloads or unattended installation. Checks never receive clipboard content. A network failure or GitHub rate limit is retryable and does not stop formatting.

With signed-update delivery configured, Sparkle presents the available version, downloads and authenticates the archive, installs it and offers to relaunch Pink. Move Pink out of a mounted image into Applications first; replacing another user's app may require authorization. On relaunch, monitoring establishes a new baseline as usual.

Without update-signing configuration, the native checker uses GitHub's latest stable release API and offers **View Release…** for a newer version. Replace Pink manually from the ZIP/DMG. It never calls a download a completed installation or installs unauthenticated code. Equal/older versions produce no downgrade offer.

Homebrew users can continue with `brew upgrade --cask mamachanko/pink/pink`. Pink never invokes Homebrew or a shell. In-app updates are optional; a subsequent Homebrew upgrade may reinstall the cask's recorded version. Pre-updater installations need one manual/Homebrew upgrade to acquire this feature; builds without a public update key also need a manual upgrade to a key-enabled release before subsequent in-app installation works.

## Maintainer setup

Sparkle **2.10.1** is pinned by immutable source commit and official archive SHA-256 in `tools/sparkle.json`. `make bootstrap` verifies the download and installs it under ignored `.tools/sparkle`. The app embeds the universal framework/helpers and Sparkle license; it needs no Node, Git, shell or developer tools at runtime. The Foundation-only core stays dependency-free.

Create a dedicated signing key on a trusted Mac, outside PR runners:

```sh
make bootstrap
.tools/sparkle/bin/generate_keys --account pink
.tools/sparkle/bin/generate_keys --account pink -p
.tools/sparkle/bin/generate_keys --account pink -x /secure/path/pink-update-key
```

Back up the Keychain key and export securely. Never commit/export it into a repository, artifact, issue or PR. This integration accepts Sparkle's current base64 **32-byte seed** export, not legacy 96-byte exports. Migrate legacy keys deliberately using upstream guidance; never truncate one.

Configure these in the existing GitHub **release environment**:

| Type | Name | Value |
| --- | --- | --- |
| Variable | `PINK_UPDATE_MODE` | `sparkle` |
| Variable | `PINK_UPDATE_PUBLIC_KEY` | Output of `generate_keys -p` |
| Secret | `PINK_UPDATE_PRIVATE_KEY` | Contents of the exported seed file |

Use environment settings or authenticated CLI input redirection; do not put private values on command lines. No broad PAT, extra server, Pages site or repository is required. The feed is `https://github.com/mamachanko/pink/releases/latest/download/appcast.xml`.

`manual` is the explicit default when no keys are configured. It publishes an informational feed with no installable enclosure. Partial/malformed keys, mismatched key pairs and unsupported modes fail before packaging. Once enabled, retain the same configuration across releases. Do not clear keys to bypass failures: existing signed-feed clients reject unsigned feeds. Key rotation needs a separately reviewed migration following Sparkle's rules, especially for ad-hoc apps.

The semantic-release prepare lifecycle uses its calculated version. After final signing/stapling, upstream `generate_appcast` processes only the final ZIP and signs its enclosure and feed. `sign_update` verifies both before publication. Deltas and external release-note loading are disabled. Final SHA256SUMS covers ZIP, DMG, manifest and feed. New releases have exactly five assets; historical four-asset releases remain verifiable. Homebrew maintenance validates the corresponding complete set.

## Trust and Apple signing

Sparkle requires Ed25519 signatures in either Apple signing mode. An ad-hoc package remains **Ad-hoc signed; not Developer ID signed; not notarized.** Updates do not remove first-install Gatekeeper requirements.

Hardened ad-hoc executables lack a Team ID for library validation. Only the ad-hoc app therefore uses `com.apple.security.cs.disable-library-validation` to load embedded Sparkle; other hardened-runtime restrictions remain. Developer ID packaging re-signs nested tools/bundles/framework inside out with the same identity and omits that entitlement. Verification checks its absence. Helper signing preserves upstream entitlements; verification compares each bundled helper with the actual pinned vendor binary. Sparkle's optional downloader sandbox source configuration is not assumed to describe the distributed binary. Signing never uses `--deep`; verification does. Developer ID/notarization credentials remain separate, governed by [release.md](release.md).

Secure delivery requires both signed feeds (`SURequireSignedFeed`) and archive validation before extraction (`SUVerifyUpdateBeforeExtraction`). Feed-signature failure expiration is disabled (`SUSignedFeedFailureExpirationInterval=0`), so validation does not weaken after repeated failures. No alternate feeds, unsigned installable archives, custom privileged installer or downgrade bypass are provided. Sparkle handles installation authorization, read-only locations, failures and relaunch. Public GitHub availability is needed only for requested updates. See [privacy.md](privacy.md).

## Verification and recovery

`make lint test` covers version ordering, bounded stable metadata, no downgrade offers, request deduplication, retry/cancellation, explicit key modes, key matching, staging cleanup and asset completeness. Tests never use the general clipboard or register login items.

On macOS, `node scripts/test-updates.mjs` generates an ephemeral key pair in memory, performs actual fixed-version preparation, verifies ZIP/feed with Sparkle and rejects tampered copies. It never publishes, replaces a user's app or saves a production key. Required CI executes it on both native architectures. Extracted/mounted package checks verify helper architectures/signatures, embedded feed/key/privacy settings, entitlement policy and clipboard-free smoke launches.

Before activating production delivery, use a disposable Mac account to test an old/new pair of key-enabled builds: current version, update offered, cancel/later, offline/retry, successful install/relaunch, read-only location, bad archive/feed, permission failure and Homebrew interaction. Record observations in `docs/verification.md`. Signing tests do not prove interactive installation. Production keys and a real install remain external setup/acceptance items until observed.

Never move tags or overwrite known-good release assets/feeds to repair an update. Publish a corrected version through semantic-release. For partial publication, follow [release recovery](release.md) and verify surviving assets before any authorized repair. Drafts/prereleases are not this update channel.

Official sources consulted on 2026-11-15: [setup](https://sparkle-project.org/documentation/), [programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/), [customization](https://sparkle-project.org/documentation/customization/), [publishing](https://sparkle-project.org/documentation/publishing/), [2.10.1 release](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.1), and pinned CLI sources. The website returned 403 here; its official source repository and release API supplied documentation/checksum. Compatibility with Pink's pinned Xcode is verified by native CI rather than inferred from upstream minimum OS.
