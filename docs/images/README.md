# README screenshots

The README shows three real Pink views:

- `menu-bar.png`: the menu-bar icon and formatting, settings and update actions.
- `settings.png`: the unified Link formats collection, Add format action and shared preview.
- `link-formats.png`: the paste-first builder with a reserved-host Jira example. The issue key is selected automatically, the paste preview is visible, and the primary action is Use for Jira links. No pattern is supplied to the capture view.

With Xcode 26.2 selected and the normal build prerequisites installed, run:

```sh
make bootstrap
node scripts/capture-readme.mjs
```

The separate documentation target uses demo settings and a unique named pasteboard. It bypasses preference loading/migration/writing and never registers login items, requests clipboard permission or checks for updates. Its development version is `0.0.0`. The menu is captured as a native screen region; Settings and the builder are captured by macOS window number after controls render. The neutral backdrop is a real window, and no screenshot pixels are altered. The command builds for its native host architecture on Apple Silicon or Intel. Capture failures do not grant or change system permissions.

Review the PNGs under `build/readme-captures/` before copying affected images here. Keep README examples, navigation, image references and alt text consistent with current behavior. Record the source revision, CI run, operating system, architecture, review date and SHA-256 checksums in `capture.txt`. Verify demo output against the formatter and check local links. Retake affected images when the UI changes. These requirements also live in root `AGENTS.md`.

CI sets `PINK_CAPTURE_TEXT_EXPORT=1` to emit checksum-tagged base64 copies of the four fixed synthetic demo outputs. This lets review tools inspect the original PNG bytes when artifact downloads are unavailable. Export is bounded to 1 MiB per file and never reads the general clipboard or user examples. Normal local captures omit this export.

The committed images were captured on macOS 15.7.9 (24G830), Intel, with Xcode 26.2 in [CI run 132](https://github.com/mamachanko/pink/actions/runs/44127980161) at source PR head `166f1fd0c1efcb84f5be2a8708178f4e5123b565`, then visually reviewed on 2026-11-17. See `capture.txt` for checksums and provenance.
