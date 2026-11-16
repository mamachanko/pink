# README captures

Capture two real views on a logged-in macOS desktop with Xcode 26.2 and the normal bootstrap prerequisites:

```sh
make bootstrap
node scripts/capture-readme.mjs
```

The separate PinkReadmeCapture target compiles the same menu/settings implementation as Pink. It uses demo settings and a unique named pasteboard, bypasses preference loading/migration/writing, and never registers login items or requests permissions. Its capture path is excluded from the shipped Pink target. The menu image is a region captured by the macOS screenshot utility; the settings image is captured from its native compositor window so layer-backed tab controls are included correctly. No mock UI or generated screenshot art is used. If desktop capture is restricted, capture fails without granting or changing system permissions.

The README images are reviewed copies of the PNG files under build/readme-captures. Keep capture OS/source provenance alongside the committed images. Retake when the UI changes; do not edit labels/states into screenshot pixels.

Committed images were captured on macOS 15.8.2 (24H232) by [CI run 88](https://github.com/mamachanko/pink/actions/runs/43842786076) on 2026-11-16, then visually inspected. They show the actual General/Link formats tabs, opt-in formatted-URL setting and persistent Save footer. See capture.txt for source revision and checksums. The neutral menu backdrop is a real window in the capture build, not a pixel edit.
