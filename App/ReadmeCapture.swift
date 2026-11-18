#if PINK_README_CAPTURE
    import AppKit
    import CoreGraphics
    import PinkCore
    import SwiftUI

    // This code is compiled only into the separate documentation capture target.
    @MainActor struct ReadmeCapturePermission: PermissionPort { var canRead: Bool { true } }

    @MainActor final class ReadmeCapture {
        let board = NSPasteboard(name: .init("Pink.readme.\(UUID())"))
        private let output: URL
        private var backdrop: NSWindow?
        private var timer: Timer?
        private var statusItem: NSStatusItem?
        private var openSettings: (@MainActor () -> NSWindow?)?
        private var stage = 0
        private var captureWindow: NSWindow?
        private var readyAt = Date.distantFuture
        private var stopped = false
        private let deadline = Date().addingTimeInterval(60)

        init() {
            guard CommandLine.arguments.count == 2 else { fatalError("Expected screenshot output directory") }
            output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
            do { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) } catch {
                fatalError("Cannot create screenshot output directory")
            }
            NSApp.appearance = NSAppearance(
                named: ProcessInfo.processInfo.environment["PINK_CAPTURE_APPEARANCE"] == "dark" ? .darkAqua : .aqua)
        }

        func start(statusItem: NSStatusItem, openSettings: @escaping @MainActor () -> NSWindow?) {
            self.statusItem = statusItem
            self.openSettings = openSettings
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.tick()
                }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
            RunLoop.main.add(timer, forMode: .eventTracking)
            // A real neutral backdrop keeps other applications out of the capture region.
            let backdrop = NSWindow(
                contentRect: NSScreen.main?.visibleFrame ?? .zero,
                styleMask: .borderless, backing: .buffered, defer: false)
            backdrop.backgroundColor = .windowBackgroundColor
            backdrop.ignoresMouseEvents = true
            backdrop.orderFrontRegardless()
            self.backdrop = backdrop
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { statusItem.button?.performClick(nil) }
        }

        private func tick() {
            guard let statusItem, let openSettings else { return }
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
                    window.setContentSize(NSSize(width: 680, height: 680))
                    self.prepare(window)
                }
            } else if stage == 2, Date() >= readyAt {
                writeWindowNumber("settings-window.json")
                stage = 3
            } else if stage == 3, captured("settings-captured") {
                // Render the actual builder with a reserved-host example.
                let formats = NSHostingView(
                    rootView: LinkFormatBuilder(
                        settings: PinkCore.Settings(), example: "https://jira.example/browse/ACME-184273",
                        save: { _ in }
                    ))
                let window = NSWindow(
                    contentRect: CGRect(x: 0, y: 0, width: 620, height: 660),
                    styleMask: [.titled, .closable], backing: .buffered, defer: false)
                window.title = "Pink Link Formats"
                window.contentView = formats
                window.center()
                window.makeKeyAndOrderFront(nil)
                prepare(window)
                stage = 4
            } else if stage == 4, Date() >= readyAt {
                writeWindowNumber("formats-window.json")
                stage = 5
            } else if stage == 5, captured("formats-captured") {
                do {
                    let evidence =
                        "Captured from Pink's real UI on macOS \(ProcessInfo.processInfo.operatingSystemVersionString). Demo settings; named pasteboard; no preference migration or writes, permission requests, or login registration.\n"
                    try evidence.write(
                        to: output.appendingPathComponent("capture.txt"), atomically: true, encoding: .utf8)
                    stage = 6
                    NSApp.terminate(nil)
                } catch { fail("capture-evidence-failed") }
            }
        }

        private func prepare(_ window: NSWindow) {
            captureWindow = window
            window.contentView?.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            // Give WindowServer and SwiftUI time to render native controls before capture.
            readyAt = Date().addingTimeInterval(0.5)
        }

        private func captured(_ name: String) -> Bool {
            FileManager.default.fileExists(atPath: output.appendingPathComponent(name).path)
        }

        private func writeWindowNumber(_ name: String) {
            guard let captureWindow else {
                fail("capture-window-missing")
                return
            }
            do {
                try JSONEncoder().encode(["number": captureWindow.windowNumber]).write(
                    to: output.appendingPathComponent(name), options: .atomic)
            } catch { fail("capture-window-metadata-failed") }
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
            statusItem = nil
            openSettings = nil
            board.releaseGlobally()
        }
    }
#endif
