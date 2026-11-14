<h1 align="center">Pink 💕</h1>

<p align="center">
  <strong>Copy full URLs. Paste readable references.</strong>
</p>

Pink makes long GitHub and GitLab references easier to read in messages, notes and reviews. Copy normally; Pink adds short, clickable links alongside your untouched original text.

<table>
  <thead><tr><th>You copy</th><th>Rich-text paste</th></tr></thead>
  <tbody>
    <tr>
      <td><code>https://github.com/<wbr>acme/widget/<wbr>pull/123</code></td>
      <td><a href="https://github.com/acme/widget/pull/123"><strong>acme/widget#123</strong></a></td>
    </tr>
    <tr>
      <td><code>https://gitlab.com/<wbr>team/platform/api/<wbr>-/merge_requests/<wbr>45</code></td>
      <td><a href="https://gitlab.com/team/platform/api/-/merge_requests/45"><strong>team/platform/api!45</strong></a></td>
    </tr>
    <tr>
      <td><code>Please review https://github.com/<wbr>acme/widget/<wbr>pull/123 and https://gitlab.com/<wbr>team/project/<wbr>-/issues/7. Thanks!</code></td>
      <td>Please review <a href="https://github.com/acme/widget/pull/123"><strong>acme/widget#123</strong></a> and <a href="https://gitlab.com/team/project/-/issues/7"><strong>team/project#7</strong></a>. Thanks!</td>
    </tr>
  </tbody>
</table>

**Plain-text paste keeps the left column exactly.** A terminal or plain-text field can select the full original URLs and message. An app accepting rich text can select the right column, with every short label pointing to its original destination. Both representations are on the same clipboard item—your app chooses what to paste.

Pink works with single links, repeated links and multiline prose. It stays in your menu bar, runs locally, and never intercepts your paste shortcut. [How paste formats work](docs/architecture.md#urls-embedded-in-prose).

<p align="center">
  <a href="https://github.com/mamachanko/pink/actions/workflows/ci.yml"><img src="https://github.com/mamachanko/pink/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI status"></a>
  &nbsp; macOS 15+ &nbsp;·&nbsp; Apple Silicon &amp; Intel &nbsp;·&nbsp; <a href="LICENSE">MIT</a>
</p>

<p align="center">
  <a href="#installation">Install</a> ·
  <a href="#usage">Usage</a> ·
  <a href="#supported-links">Supported links</a> ·
  <a href="#development">Development</a>
</p>

<table align="center">
  <tr><th>In the menu bar</th><th>Settings</th></tr>
  <tr>
    <td align="center" valign="top"><a href="docs/images/menu-bar.png"><img src="docs/images/menu-bar.png" width="261" alt="Pink’s menu-bar icon and menu, with formatting controls, Settings, About and Quit."></a></td>
    <td align="center" valign="top"><a href="docs/images/settings.png"><img src="docs/images/settings.png" width="440" alt="Pink Settings showing automatic formatting, GitHub and GitLab host rules, enterprise configuration and opt-in launch at login."></a></td>
  </tr>
</table>

<p align="center"><sub>Actual Pink UI on macOS, using demo settings. <a href="docs/images/README.md">Capture details</a>.</sub></p>

## Installation

Requires **macOS 15 or later**. Each release contains a universal app for Apple Silicon and Intel.

### Homebrew

```sh
brew tap mamachanko/pink https://github.com/mamachanko/pink.git
brew install --cask mamachanko/pink/pink
```

Update with `brew upgrade --cask mamachanko/pink/pink`. The custom tap lives in this repository and follows reviewed, checksum-pinned releases. Automation keeps one update PR current and starts its checks automatically; a direct download may be newer while that PR awaits merge.

### Direct download

Download a ZIP or DMG from [GitHub Releases](https://github.com/mamachanko/pink/releases/latest). Extract the ZIP or drag **Pink.app** from the DMG into **Applications**, then open it.

> [!IMPORTANT]
> Current packages are **Ad-hoc signed; not Developer ID signed; not notarized.** If macOS blocks launch, use the per-app **Open Anyway** option in **Privacy & Security** when offered, or [build from source](#development). Keep Gatekeeper enabled. See the [installation guide](docs/installation.md) for details.

## Usage

1. Open Pink and choose **Enable** to allow local clipboard processing.
2. Copy a supported URL, or text containing several supported URLs.
3. Paste normally. Your app chooses whether to use rich or plain text.

Pink lives in the menu bar, with no Dock icon. Its menu gives you:

| Action | What it does |
| --- | --- |
| **Pause automatic formatting** | Stop processing new copies. Enable it again to resume. |
| **Format current clipboard** | Process content you already copied. |
| **Restore original clipboard** | Restore the last original item while Pink still owns the current clipboard. It cannot change text already pasted. |
| **Settings** | Manage host rules, automatic formatting and opt-in launch at login. macOS may require login-item approval. |

Enabling or resuming Pink leaves existing clipboard content alone. Use **Format current clipboard** to process it explicitly.

A message containing a pull request and a merge request can appear as:

> Please review [acme/widget#123](https://github.com/acme/widget/pull/123) and [team/project!45](https://gitlab.com/team/project/-/merge_requests/45).

Each label keeps its own destination. Plain paste retains the entire original message, including both full URLs.

## Supported links

`github.com` and `gitlab.com` are enabled by default over HTTPS.

| Service | URL path | Short label |
| --- | --- | --- |
| GitHub issue | `/owner/repo/issues/123` | `owner/repo#123` |
| GitHub pull request | `/owner/repo/pull/123` | `owner/repo#123` |
| GitLab issue | `/group/project/-/issues/123` | `group/project#123` |
| GitLab merge request | `/group/project/-/merge_requests/123` | `group/project!123` |

Nested GitLab namespaces stay in the label. Trailing slashes are supported, along with GitHub `files`, `commits` and `checks` subpages and GitLab merge-request `diffs`, `commits` and `pipelines` subpages. Queries, fragments and display case are preserved.

### Enterprise installations

Add a rule in **Settings → Host rules** for your GitHub or GitLab installation. Rules support an exact hostname, optional port, installation base path and enabled state. HTTP requires an explicit opt-in for that particular private host; HTTPS remains the default. Wildcards and overlapping enabled rules are rejected. See [matching rules](docs/architecture.md) for port and path-boundary details.

## Privacy and permissions

Processing stays on your Mac. Pink has no accounts, telemetry, network lookups, clipboard history or automatic updater. Only settings are saved. Clipboard contents and the single temporary restoration snapshot are never logged or persisted.

Pink does not need Accessibility, Input Monitoring or Screen Recording permissions. Its initial **Enable** consent is separate from macOS clipboard policy. On macOS 15.4+, an Ask/Deny policy stops monitoring; review the per-app **Paste from Other Apps** setting where available, then use **Retry**. See [privacy](docs/privacy.md) and [permission guidance](docs/installation.md#clipboard-permissions).

## Limitations

- **Paste behavior depends on the app.** An app can select plain text or strip links. App-specific compatibility has not yet been manually verified; see the [compatibility record](docs/compatibility.md).
- **An immediate paste can beat the watcher.** Pink checks about every 200 ms. The safe fallback is your original text. It never intercepts paste, simulates keys or inspects the destination app.
- **Some clipboard items are deliberately skipped.** These include files, images, multiple items, unknown types, protected/temporary/generated/remote markers, existing HTML and named hyperlinks. Unmarked sensitive content cannot always be identified.
- **Text is limited to 8 KiB per item.** Bare URLs need clear boundaries. Named Markdown destinations and HTML source are not reformatted; ambiguous adjacent URLs are left unchanged. Existing raw RTF links must agree with the proposed targets.

Clipboard writes also have a small, unavoidable race with other applications. Pink checks for changes before writing and before offering restoration. The [architecture notes](docs/architecture.md) describe that boundary.

## Development

Build prerequisites: **Xcode 26.2**, **Node.js 24.22.1**, npm and Git. The installed app runs without those tools or network access.

```sh
git clone https://github.com/mamachanko/pink.git
cd pink
make bootstrap
make doctor
make verify
```

| Command | Purpose |
| --- | --- |
| `make bootstrap` | Install pinned build and verification tools. |
| `make doctor` | Check prerequisites and print architecture/toolchain versions. |
| `make lint` | Check Swift formatting, workflows and shell scripts. |
| `make test` | Run Swift and release-tooling tests; include named AppKit pasteboards on macOS. |
| `make build` | Build the universal app with local version `0.0.0`. |
| `make package` | Create and verify an ad-hoc ZIP, DMG, checksums and build manifest. |
| `make verify` | Run lint, tests and packaging together. |

Builds go to `build/` and packages to `dist/`; these commands do not install the app. The Foundation-only core also supports portable testing on Linux with Swift 6.0+ (verified with Swift 6.2). Native tests use unique named pasteboards, never the general clipboard; smoke mode `--smoke-test` exits before clipboard setup.

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), then see the [architecture](docs/architecture.md), [requirements](docs/spec.md) and [verification results](docs/verification.md). Report vulnerabilities using [SECURITY.md](SECURITY.md).

Releases are automated with semantic-release after verification. [GitHub Releases](https://github.com/mamachanko/pink/releases) are the changelog. Maintainers can find the [release process](docs/release.md), [Homebrew maintenance](docs/homebrew.md) and [repository setup](docs/repository-setup.md) in `docs/`.

## Uninstall

Disable **launch at login** in Settings and quit Pink, then run:

```sh
brew uninstall --cask mamachanko/pink/pink
```

For a manual installation, delete **Pink.app**. Ordinary uninstall preserves preferences; use Homebrew’s `--zap` only if you also want to remove them. See [removal and legacy upgrades](docs/installation.md#uninstall) for details.

## License

Pink is available under the [MIT License](LICENSE).
