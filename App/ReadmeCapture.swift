#if PINK_README_CAPTURE
    import AppKit
    import CoreGraphics
    import PinkCore

    // This code is compiled only into the separate documentation capture target.
    @MainActor struct ReadmeCapturePermission: PermissionPort { var canRead: Bool { true } }

    @MainActor final class ReadmeCapture {
        let board = NSPasteboard(name: .init("Pink.readme.\(UUID())"))
        private let output: URL
        private var timer: Timer?
        private var stage = 0
        private var stopped = false
        private let deadline = Date().addingTimeInterval(60)

        init() {
            guard CommandLine.arguments.count == 2 else { fatalError("Expected screenshot output directory") }
            output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
            do { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) } catch {
                fatalError("Cannot create screenshot output directory")
            }
            NSApp.appearance = NSAppearance(named: .aqua)
        }

        func start(statusItem: NSStatusItem, openSettings: @escaping @MainActor () -> NSWindow?) {
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.tick(statusItem: statusItem, openSettings: openSettings)
                }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
            RunLoop.main.add(timer, forMode: .eventTracking)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { statusItem.button?.performClick(nil) }
        }

        private func tick(statusItem: NSStatusItem, openSettings: @escaping @MainActor () -> NSWindow?) {
            guard Date() < deadline else {
                fail("capture-timeout")
                return
            }
            if stage == 0, let rect = menuRegion(statusItem: statusItem) {
                do {
                    let coordinates = [
                        "x": Int(rect.minX), "y": Int(rect.minY), "width": Int(rect.width), "height": Int(rect.height),
                    ]
                    try JSONEncoder().encode(coordinates).write(
                        to: output.appendingPathComponent("menu-region.json"), options: .atomic)
                    stage = 1
                } catch { fail("menu-region-failed") }
            } else if stage == 1,
                FileManager.default.fileExists(atPath: output.appendingPathComponent("menu-captured").path)
            {
                stage = 2
                statusItem.menu?.cancelTracking()
                DispatchQueue.main.async { [weak self] in
                    guard let self, let window = openSettings() else {
                        self?.fail("settings-window-failed")
                        return
                    }
                    window.contentView?.layoutSubtreeIfNeeded()
                    window.displayIfNeeded()
                    // Draw the actual window frame and its hosted SwiftUI/AppKit controls.
                    guard let view = window.contentView?.superview,
                        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)
                    else {
                        self.fail("settings-bitmap-failed")
                        return
                    }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let png = bitmap.representation(using: .png, properties: [:]) else {
                        self.fail("settings-encoding-failed")
                        return
                    }
                    do {
                        try png.write(to: self.output.appendingPathComponent("settings.png"), options: .atomic)
                        let evidence =
                            "Captured from Pink's real UI on macOS \(ProcessInfo.processInfo.operatingSystemVersionString). Demo settings; named pasteboard; no preference migration or writes, permission requests, or login registration.\n"
                        try evidence.write(
                            to: self.output.appendingPathComponent("capture.txt"), atomically: true, encoding: .utf8)
                        self.stage = 3
                        NSApp.terminate(nil)
                    } catch { self.fail("settings-write-failed") }
                }
            }
        }

        private func menuRegion(statusItem: NSStatusItem) -> CGRect? {
            guard
                let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                    as? [[String: Any]]
            else { return nil }
            let own = infos.filter {
                ($0[kCGWindowOwnerPID as String] as? Int) == Int(ProcessInfo.processInfo.processIdentifier)
            }
            func bounds(_ info: [String: Any]) -> CGRect? {
                guard let b = info[kCGWindowBounds as String] as? [String: Any],
                    let x = b["X"] as? Double, let y = b["Y"] as? Double,
                    let w = b["Width"] as? Double, let h = b["Height"] as? Double
                else { return nil }
                return CGRect(x: x, y: y, width: w, height: h)
            }
            guard
                let menu = own.filter({
                    ($0[kCGWindowLayer as String] as? Int ?? 0) >= NSWindow.Level.popUpMenu.rawValue
                })
                .compactMap(bounds).filter({ $0.height > 40 }).max(by: { $0.width * $0.height < $1.width * $1.height }),
                let number = statusItem.button?.window?.windowNumber,
                let button = own.first(where: { ($0[kCGWindowNumber as String] as? Int) == number }).flatMap(bounds)
            else { return nil }
            return menu.union(button).insetBy(dx: -10, dy: -6).intersection(
                CGRect(
                    x: 0, y: 0, width: NSScreen.main?.frame.width ?? 2000, height: NSScreen.main?.frame.height ?? 1200)
            ).integral
        }

        private func fail(_ category: String) {
            try? category.write(to: output.appendingPathComponent("failure.txt"), atomically: true, encoding: .utf8)
            stop()
            NSApp.terminate(nil)
        }
        func stop() {
            guard !stopped else { return }
            stopped = true
            timer?.invalidate()
            timer = nil
            board.releaseGlobally()
        }
    }
#endif
