# RefPaste

A native macOS 15+ menu-bar utility that adds short rich hyperlinks to copied GitHub and GitLab references. The exact original URL remains the plain-text representation.

`https://github.com/acme/widget/pull/123` → **acme/widget#123** in a rich-text receiver, linked to the original URL. Terminals and plain editors get the original URL. The receiver chooses; RefPaste never intercepts paste or inspects the destination.

Install a verified release ZIP or drag the app from the DMG to Applications, then open it and choose Enable. **No release is published by this implementation task.** Default packages are **Ad-hoc signed; not Developer ID signed; not notarized.** macOS may block them. Review the source, build locally, or use the per-app Open Anyway option in Privacy & Security when offered. Never disable Gatekeeper globally. Developer ID releases require configured signing and notarization.

The link menu provides Enable/Pause, Format current clipboard, safe Restore original clipboard, Settings, About and Quit. On activation it leaves existing content alone. Restore changes the current clipboard only. The app has no normal Dock icon. Launch at login is opt-in in Settings and may need approval in Login Items.

Supported HTTPS routes:

- GitHub `/owner/repo/pull/N`, `/owner/repo/issues/N`, with trailing slash or `files`, `commits`, `checks` review suffix.
- GitLab `/namespace/project/-/issues/N` and `/merge_requests/N`; merge requests also accept `diffs`, `commits`, `pipelines`. Nested namespaces are retained. Issues use `#`; merge requests use `!`.

Settings supports exact enterprise hosts, service, optional explicit port, installation prefix, enabled state and individual private-host HTTP opt-in. Rules cannot overlap. No wildcards or public-host HTTP. Prefixes are case-sensitive; host matching is case-insensitive. Explicit URL ports require matching explicit rule ports. Conservative ASCII path names only; unreserved percent escapes are accepted, while encoded separators are skipped. Query and fragment stay in the target.

All processing is local. No account, telemetry, servers, lookup, clipboard history or updater. Only settings are persisted. Unknown types, files/images, sensitive/temporary/generated/remote markers, multiple items, existing HTML/named rich links and mismatched representations are skipped. Unmarked sensitive content cannot be reliably identified. See [privacy](docs/privacy.md).

Initial consent is separate from OS privacy controls. On macOS 15.4+ Ask/Deny clipboard policies stop monitoring. Where provided, review System Settings → Privacy & Security → Paste from Other Apps, then use Retry. RefPaste does not request Accessibility, Input Monitoring or Screen Recording.

Polling runs about every 200 ms. Immediate paste can beat it; original URL is the fallback. Receivers may choose plain text or strip rich links; compatibility has **not been verified** on this Linux development host. See [actual compatibility status](docs/compatibility.md). External clipboard writes have an unavoidable race with clear/write. No atomicity claim.

Development requires Xcode 26.2 on macOS, Git, Node 24.22.1 and npm. Portable core can be tested on Linux with Swift 6.0+ (verified here using Swift 6.2). App runs without any of those tools or network.

```sh
make bootstrap  # npm ci; macOS builds pinned XcodeGen
make doctor     # print tools/architecture and missing native prerequisites
make lint       # Swift formatting, YAML/action pin checks, shell syntax
make test       # Swift tests (includes named AppKit tests on macOS), release-tool tests
make build      # universal app, local version 0.0.0/build 1
make package    # ad-hoc ZIP, drag-install DMG, manifest, checksums and verification
make verify     # lint + test + package
```

Build output lives in `build/`, artifacts in `dist/`; nothing installs automatically. App smoke mode `--smoke-test` exits before clipboard setup. Native tests use unique named boards, never your general clipboard. See [contribution](CONTRIBUTING.md), [architecture](docs/architecture.md), [verification](docs/verification.md), [requirements](docs/spec.md).

Releases use semantic-release on main after reusable verification; GitHub Releases are the changelog. See [release contract](docs/release.md) and [repository setup](docs/repository-setup.md). To uninstall: disable launch at login, quit, delete the app, then optionally remove its `io.refpaste.app` UserDefaults preferences. No clipboard history files exist.
