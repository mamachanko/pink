import AppKit
import OSLog
import PinkCore
import PinkPlatform
import ServiceManagement
import SwiftUI

@main struct PinkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private var monitor: ClipboardMonitor!
    private var settings = PinkCore.Settings()
    private let settingsStore = SettingsStore()
    #if PINK_README_CAPTURE
        private var readmeCapture: ReadmeCapture?
    #endif
    private var window: NSWindow?
    private var resumeAfterSuspension = false
    private var lastLoggedState: MonitorState?
    private let log = Logger(subsystem: "io.github.mamachanko.pink", category: "state")
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("--smoke-test") {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        #if PINK_README_CAPTURE
            let capture = ReadmeCapture()
            readmeCapture = capture
            settings.consent = true
            settings.automatic = true
            configure(board: NativeBoard(capture.board), permission: ReadmeCapturePermission())
            capture.start(statusItem: item) { [weak self] in
                self?.showSettings()
                return self?.window
            }
        #else
            do { settings = try settingsStore.load() } catch {
                settings = PinkCore.Settings()
                log.error("invalid-settings")
            }
            configure(board: NativeBoard(.general), permission: NativePermission())
            if !settings.consent { showConsent() }
        #endif
    }
    private func configure(board: any PasteboardPort, permission: any PermissionPort) {
        monitor = ClipboardMonitor(
            board: board, builder: NativeRepresentations(), permission: permission,
            scheduler: TimerScheduler(), parser: try! Parser(rules: settings.rules))
        monitor.onChange = { [weak self] in self?.refresh() }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "💕"
        item.button?.font = .systemFont(ofSize: 16)
        item.button?.toolTip = "Pink"
        item.button?.setAccessibilityLabel("Pink")
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self, selector: #selector(suspendMonitoring), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(
            self, selector: #selector(suspendMonitoring), name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil)
        center.addObserver(self, selector: #selector(rebaseline), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(
            self, selector: #selector(rebaseline), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        if settings.consent && settings.automatic { monitor.enable() }
        refresh()
    }
    func applicationWillTerminate(_ notification: Notification) {
        monitor?.pause()
        #if PINK_README_CAPTURE
            readmeCapture?.stop()
        #endif
    }
    private func save() {
        #if PINK_README_CAPTURE
            return
        #else
            do { try settingsStore.save(settings) } catch { log.error("settings-save-failed") }
        #endif
    }
    @objc private func suspendMonitoring() {
        resumeAfterSuspension = resumeAfterSuspension || monitor.state == .active
        monitor.pause()
    }
    @objc private func rebaseline() {
        if resumeAfterSuspension && settings.automatic && settings.consent {
            resumeAfterSuspension = false
            monitor.enable()
        } else {
            monitor.baseline()
        }
    }
    private func showConsent() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Enable Pink?"
        alert.informativeText =
            "Pink checks new clipboard items locally and adds a short rich hyperlink to supported GitHub and GitLab URLs. Plain text stays the original URL. Clipboard contents are never stored or sent. Some unmarked sensitive content cannot be identified."
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Not now")
        if alert.runModal() == .alertFirstButtonReturn {
            settings.consent = true
            settings.automatic = true
            save()
            monitor.enable()
        }
    }
    private func refresh() {
        guard item != nil else { return }
        let menu = NSMenu()
        let status = NSMenuItem(title: "Pink — \(monitor.state.rawValue)", action: nil, keyEquivalent: "")
        menu.addItem(status)
        func add(_ title: String, _ action: Selector, _ key: String = "", enabled: Bool = true) {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
            entry.target = self
            entry.isEnabled = enabled
            menu.addItem(entry)
        }
        menu.autoenablesItems = false
        add(settings.automatic ? "Pause automatic formatting" : "Enable automatic formatting", #selector(toggle))
        add("Format current clipboard", #selector(format))
        add("Restore original clipboard", #selector(restore), enabled: monitor.canRestore)
        if monitor.state == .error || monitor.state == .permissionNeeded {
            add("Retry clipboard access…", #selector(retry))
        }
        menu.addItem(.separator())
        add("Settings…", #selector(showSettings), ",")
        add("About Pink…", #selector(about))
        add("Quit Pink", #selector(quit), "q")
        item.menu = menu
        if lastLoggedState != monitor.state {
            log.info("state: \(self.monitor.state.rawValue, privacy: .public)")
            lastLoggedState = monitor.state
        }
    }
    @objc private func toggle() {
        if !settings.consent {
            showConsent()
            return
        }
        settings.automatic.toggle()
        save()
        if settings.automatic { monitor.enable() } else { monitor.pause() }
    }
    @objc private func format() { if settings.consent { monitor.process() } else { showConsent() } }
    @objc private func restore() { monitor.restore() }
    @objc private func retry() {
        let alert = NSAlert()
        alert.messageText = "Clipboard access"
        alert.informativeText =
            "If macOS asks, allow Pink to paste. Where available, review System Settings → Privacy & Security → Paste from Other Apps. Pink does not need Accessibility, Input Monitoring, or Screen Recording. Retry establishes a new baseline."
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            if settings.automatic { monitor.enable() } else { monitor.baseline() }
        }
    }
    @objc private func showSettings() {
        let view = SettingsView(initial: settings) { [weak self] value in
            guard let self else { return }
            self.settings = value
            self.save()
            self.monitor.parser = try! Parser(rules: value.rules)
            if value.automatic && value.consent { self.monitor.enable() } else { self.monitor.pause() }
        }
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Pink Settings"
        window.setContentSize(NSSize(width: 640, height: 660))
        window.contentMinSize = NSSize(width: 640, height: 660)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func about() {
        let bundle = Bundle.main
        let alert = NSAlert()
        alert.messageText =
            "Pink \(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")"
        alert.informativeText =
            "Build \(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0")\nMIT License · Copyright © 2026 Max Brauer\nLocal clipboard formatting. No telemetry.\nRestore affects the clipboard, not previously pasted text."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Repository")
        alert.addButton(withTitle: "Releases")
        let result = alert.runModal()
        if result == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/mamachanko/pink")!)
        }
        if result == .alertThirdButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/mamachanko/pink/releases")!)
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
struct SettingsView: View {
    @State var value: PinkCore.Settings
    @State private var host = ""
    @State private var base = ""
    @State private var port = ""
    @State private var service = Service.github
    @State private var http = false
    @State private var error = ""
    @State private var loginStatus = SMAppService.mainApp.status
    let apply: (PinkCore.Settings) -> Void
    init(initial: PinkCore.Settings, apply: @escaping (PinkCore.Settings) -> Void) {
        _value = State(initialValue: initial)
        self.apply = apply
    }
    var body: some View {
        Form {
            Toggle("Automatic formatting", isOn: $value.automatic).disabled(!value.consent)
            Text("Processing is local. Plain paste keeps the exact URL. Immediate paste may beat the watcher.").font(
                .caption)
            Section("Host rules") {
                List {
                    ForEach(value.rules.indices, id: \.self) { i in
                        HStack {
                            Toggle(value.rules[i].host + value.rules[i].basePath, isOn: $value.rules[i].enabled)
                            Text(value.rules[i].service.rawValue).foregroundStyle(.secondary)
                            Button("Remove") { value.rules.remove(at: i) }
                        }
                    }
                }.frame(height: 80)
                Picker("Service", selection: $service) {
                    ForEach(Service.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                TextField("Exact hostname", text: $host)
                HStack {
                    TextField("Port (optional)", text: $port, prompt: Text("Port (optional)")).labelsHidden()
                    TextField("Base path (optional)", text: $base, prompt: Text("Base path (optional)")).labelsHidden()
                }
                Toggle("Allow HTTP for this private host", isOn: $http)
                Button("Add host rule") {
                    guard port.isEmpty || Int(port) != nil else {
                        error = "Invalid port"
                        return
                    }
                    var next = value
                    next.rules.append(
                        HostRule(service: service, host: host, port: Int(port), basePath: base, allowHTTP: http))
                    do {
                        _ = try Parser(rules: next.rules)
                        value = next
                        host = ""
                        base = ""
                        port = ""
                        error = ""
                    } catch { self.error = "Invalid or overlapping host rule" }
                }
            }
            Section("Launch at login (opt-in)") {
                Text(loginDescription)
                HStack {
                    Button(loginStatus == .enabled ? "Disable login launch" : "Enable login launch") {
                        do {
                            if loginStatus == .enabled {
                                try SMAppService.mainApp.unregister()
                            } else {
                                try SMAppService.mainApp.register()
                            }
                            error = ""
                        } catch { self.error = "Login registration failed" }
                        loginStatus = SMAppService.mainApp.status
                    }
                    Button("Login Items settings") { SMAppService.openSystemSettingsLoginItems() }
                    Button("Refresh") { loginStatus = SMAppService.mainApp.status }
                }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red).accessibilityLabel(error) }
            Button("Save settings") {
                do {
                    _ = try Parser(rules: value.rules)
                    apply(value)
                    error = "Saved"
                } catch { self.error = "Invalid or overlapping host rules" }
            }.keyboardShortcut(.defaultAction)
        }.formStyle(.grouped).padding().frame(minWidth: 640, minHeight: 660)
    }
    private var loginDescription: String {
        switch loginStatus {
        case .enabled: "Enabled"
        case .requiresApproval: "Approval required in Login Items settings"
        case .notRegistered: "Not registered"
        case .notFound: "Application service unavailable"
        @unknown default: "Unknown state"
        }
    }
}
