# README screenshots

The README currently shows the unchanged menu capture. The General settings image is an archived capture of the previous interface and is not displayed as the current UI. The obsolete builder capture has been removed while standardizing examples on ACME. Retake both settings views on macOS before restoring them to the README:

- `menu-bar.png`: the menu-bar icon and formatting, settings and update actions.
- `settings.png`: the General settings tab with update controls, the opt-in formatted-URL setting, automatic formatting and service hosts. The form scrolls to additional controls below the visible viewport.
- `link-formats.png` (pending recapture): the actual link-format builder with a reserved-host Jira pattern, label template, captured issue value and live hyperlink preview.

Run `node scripts/capture-readme.mjs` on a macOS desktop to retake them. The separate documentation target uses demo settings and a unique named pasteboard without changing preferences, requesting clipboard permission, registering a login item or performing an update check. Its development version is `0.0.0`. The menu is captured as a native screen region; the Settings and builder windows are captured by macOS window number after native controls have rendered. The neutral menu backdrop is a real window in the capture build. Capture failures do not grant or change system permissions.

With Xcode 26.2 selected and the normal build prerequisites installed:

```sh
make bootstrap
node scripts/capture-readme.mjs
```

Review the actual PNGs under `build/readme-captures/` before copying the affected images into this directory. Keep the README demo, labels, navigation, image references and alt text consistent with current behavior. Record the source revision, CI run (when used), operating system, review date and SHA-256 checksums in `capture.txt`. Verify the demo against the formatter and check relative links and image references. Retake affected images when the UI changes; do not alter screenshot pixels to represent a different state. These requirements also live in the root `AGENTS.md`.

The committed images were captured on macOS 15.8.2 (24H232) and visually inspected. `menu-bar.png` and `settings.png` come from [CI run 88](https://github.com/mamachanko/pink/actions/runs/43842786076), source `01ff3a646b1bd74143abaff4c8e49083f9aaead8`, reviewed on 2026-11-16; Settings shows the opt-in formatted-URL control. Each PNG is an unmodified native capture. See `capture.txt` for provenance and checksums.

The redesigned collection and Jira editor were captured successfully by [CI run 100](https://github.com/mamachanko/pink/actions/runs/43871951434), source `b2736ebf8bfdf1db51d4b465319d00bc7dd054a6`. The [capture artifact](https://github.com/mamachanko/pink/actions/runs/43871951434/artifacts/14228248053) is available for review. Download into this workspace is blocked by its enforced network allowlist, so these new PNGs have not been visually reviewed or substituted for the archived images.
