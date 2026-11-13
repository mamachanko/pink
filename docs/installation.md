# Installing and removing Pink

Pink requires macOS 15 or later. Release applications support Apple Silicon and Intel. Use the Homebrew commands or direct-download instructions in the [README](../README.md#installation).

## Release downloads and macOS approval

Download from the repository’s [GitHub Releases](https://github.com/mamachanko/pink/releases). ZIP and DMG releases include `SHA256SUMS` and `build-info.json` for checking integrity, source commit, toolchain and signing status. Follow the [release documentation](release.md) for artifact verification.

Current packages are **Ad-hoc signed; not Developer ID signed; not notarized.** If macOS blocks the application, review its source and origin. Use the per-app **Open Anyway** option in **System Settings → Privacy & Security** when macOS offers it, or build locally using the README’s prerequisites. Never disable Gatekeeper globally. Developer ID signing and notarization require the maintainer credentials described in the release documentation.

Move **Pink.app** into **Applications**, open it and choose **Enable** to allow local clipboard processing. Launch at login is a separate, opt-in setting and may require macOS approval. Homebrew installation does not launch Pink, register login items, grant permissions or remove quarantine.

## Clipboard permissions

Pink’s initial consent is separate from OS clipboard controls. It does not request Accessibility, Input Monitoring or Screen Recording permissions.

On macOS 15.4+, Pink checks the available clipboard policy before monitoring. An Ask/Deny policy stops processing without repeatedly prompting. Where macOS provides the setting, review **System Settings → Privacy & Security → Paste from Other Apps** for Pink, then use its user-initiated **Retry** action. Availability and presentation depend on the OS version. On earlier systems, a failed clipboard read stops monitoring and shows an error. See [privacy](privacy.md) for the policy and [compatibility](compatibility.md) for what has actually been tested.

## Uninstall

1. Disable launch at login in Pink’s Settings.
2. Quit Pink from its menu-bar menu.
3. Run `brew uninstall --cask mamachanko/pink/pink`, or delete **Pink.app** if installed manually.

Ordinary uninstall preserves preferences. To intentionally remove current and legacy preferences through Homebrew, use:

```sh
brew uninstall --cask --zap mamachanko/pink/pink
```

For a manual installation, preferences use the UserDefaults domain `io.github.mamachanko.pink`. The legacy domain is `io.refpaste.app`. Remove those preferences only if you intend to reset settings. There are no clipboard-history files to delete.

## Upgrading from RefPaste

Pink imports valid local settings once from `io.refpaste.app` when Pink has no saved settings. It does not migrate clipboard data or override existing Pink preferences.

Quit the old application and disable its login item before removing it. Enable launch at login for Pink separately if wanted. Pink’s bundle identity has its own macOS clipboard approval, so the OS may ask for access again.

If a mounted disk image or installed application still says **RefPaste**, check its version: v1.0.0 predates the rename. Eject that image and use a current [Pink release](https://github.com/mamachanko/pink/releases/latest). Package verification now requires the volume and its sole application bundle to be named Pink. Historical release files are retained rather than silently replaced.
