# README captures

Capture two real views on a logged-in macOS desktop with Xcode 26.2 and the normal bootstrap prerequisites:

```sh
make bootstrap
node scripts/capture-readme.mjs
```

The separate PinkReadmeCapture target compiles the same menu/settings implementation as Pink. It uses demo settings and a unique named pasteboard, bypasses preference loading/migration/writing, and never registers login items or requests permissions. Its capture path is excluded from the shipped Pink target. The menu image is a region captured by the macOS screenshot utility; the settings image is drawn from the actual AppKit window hosting the SwiftUI view. No mock UI or generated screenshot art is used. If desktop capture is restricted, capture fails without granting or changing system permissions.

The README images are reviewed copies of the PNG files under build/readme-captures. Keep capture OS/source provenance alongside the committed images. Retake when the UI changes; do not edit labels/states into screenshot pixels.

Committed images were captured on macOS 15.8.2 (24H232) by [capture run 4](https://github.com/mamachanko/pink/actions/runs/43399485800), then visually inspected. See capture.txt for source revision and checksums. The neutral menu backdrop is a real window in the capture build, not a pixel edit. The settings layout shown is shared with the shipping app; capture revealed clipped fields, which were corrected with the native grouped form and a suitable minimum window size.
