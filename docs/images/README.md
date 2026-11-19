# README screenshots

The README shows four real Pink views:

- `menu-bar.png`: the menu-bar icon and formatting, settings and update actions.
- `settings.png`: the unified Link formats collection, rose Add format action and included website formats, visible More menu, bordered row options and shared preview.
- `general.png`: the actual General section, selected through the app’s native section picker, with Show link icons enabled.
- `link-formats.png`: the paste-first builder with a reserved-host Jira example. The issue key is selected automatically, the ticket-icon paste preview is visible, and the primary action is Use for Jira links. The selected part also has a checkmark. No pattern is supplied to the capture view.

With Xcode 26.2 selected and the normal build prerequisites installed, run:

```sh
make bootstrap
node scripts/capture-readme.mjs
PINK_CAPTURE_APPEARANCE=dark node scripts/capture-readme.mjs build/readme-captures/dark
```

The separate documentation target uses demo settings and a unique named pasteboard. It bypasses preference loading/migration/writing and never registers login items, requests clipboard permission or checks for updates. Its development version is `0.0.0`. The menu is captured as a native screen region; Settings, General and the builder are captured by macOS window number after controls render. The neutral backdrop is a real window, and no screenshot pixels are altered. The command builds for its native host architecture on Apple Silicon or Intel. Capture failures do not grant or change system permissions.

Review the PNGs under `build/readme-captures/` before copying affected images here. Keep README examples, navigation, image references and alt text consistent with current behavior. Record the source revision, CI run, operating system, architecture, review date and SHA-256 checksums in `capture.txt`. Verify demo output against the formatter and check local links. Retake affected images when the UI changes. These requirements also live in root `AGENTS.md`.

The README uses matching light and dark image sources. The dark capture sets only the documentation app’s appearance to darkAqua; it does not change system settings. The menu bar/menu keeps its native system appearance. Both sets are committed, and both are visually reviewed.

CI sets `PINK_CAPTURE_TEXT_EXPORT=1` to emit checksum-tagged base64 copies of the five fixed synthetic demo outputs (`menu-bar.png`, `settings.png`, `general.png`, `link-formats.png` and `capture.txt`) per appearance. This lets review tools inspect the original PNG bytes when artifact downloads are unavailable. Export is bounded to 1 MiB per file and never reads the general clipboard or user examples. Normal local captures omit this export.

The committed images were captured on macOS 15.7.9 (24G830), Intel, with Xcode 26.2 in [CI run 162](https://github.com/mamachanko/pink/actions/runs/44543792877) at source PR head `c3482c30b0e96c96f49f614df8978b7d58fe586a`, then visually reviewed in light and dark appearance on 2026-11-19. See `capture.txt` for checksums and provenance.
