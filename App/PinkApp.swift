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
    private var preferences: SettingsModel!
    private var settings: PinkCore.Settings { preferences.value }
    private let settingsStore = SettingsStore()
    private let updates = UpdateController()
    #if PINK_README_CAPTURE
        private var readmeCapture: ReadmeCapture?
    #endif
    private var window: NSWindow?
    private var resumeAfterSuspension = false
    private var lastLoggedState: MonitorState?
    private let log = Logger(subsystem: "io.github.mamachanko.pink", category: "state")
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("--update-smoke-test") {
            if !updates.verifyConfigurationForSmokeTest() { exit(1) }
            NSApp.terminate(nil)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--smoke-test") {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        updates.onChange = { [weak self] in self?.refresh() }
        #if PINK_README_CAPTURE
            let capture = ReadmeCapture()
            readmeCapture = capture
            var demo = PinkCore.Settings()
            demo.consent = true
            demo.automatic = true
            demo.linkRules = [LinkRule.templates[0]]
            preferences = try! SettingsModel(initial: demo, persist: { _ in })
            configure(board: NativeBoard(capture.board), permission: ReadmeCapturePermission())
            capture.start(statusItem: item) { [weak self] in
                self?.showSettings()
                return self?.window
            }
        #else
            let initial: PinkCore.Settings
            do { initial = try settingsStore.load() } catch {
                initial = PinkCore.Settings()
                log.error("invalid-settings")
            }
            let store = settingsStore
            preferences = try! SettingsModel(initial: initial, persist: store.save)
            configure(board: NativeBoard(.general), permission: NativePermission())
            if !settings.consent { showConsent() }
        #endif
    }
    private func configure(board: any PasteboardPort, permission: any PermissionPort) {
        monitor = ClipboardMonitor(
            board: board, builder: NativeRepresentations(rewriteFormattedURLs: settings.rewriteFormattedURLs),
            permission: permission,
            scheduler: TimerScheduler(), parser: try! Parser(settings: settings))
        preferences.onChange = { [weak self] previous, current in
            guard let self else { return }
            if previous.rules != current.rules || previous.linkRules != current.linkRules
                || previous.showLinkIcons != current.showLinkIcons
            {
                self.monitor.parser = try! Parser(settings: current)
            }
            if previous.rewriteFormattedURLs != current.rewriteFormattedURLs {
                self.monitor.builder = NativeRepresentations(rewriteFormattedURLs: current.rewriteFormattedURLs)
            }
            let wasAutomatic = previous.consent && previous.automatic
            let isAutomatic = current.consent && current.automatic
            if wasAutomatic != isAutomatic {
                if isAutomatic {
                    self.monitor.enable()
                } else {
                    self.resumeAfterSuspension = false
                    self.monitor.pause()
                }
            }
            self.refresh()
        }
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
        updates.stop()
        monitor?.pause()
        #if PINK_README_CAPTURE
            readmeCapture?.stop()
        #endif
    }
    private func editSettings(_ change: (inout PinkCore.Settings) -> Void) {
        do { try preferences.edit(change) } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t save settings"
            alert.informativeText = "Your previous settings are still active. Try again."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
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
            "Pink checks new clipboard items locally and adds short rich hyperlinks to URLs matching your link formats, including links within prose. Plain paste keeps the exact original text. Clipboard contents are never stored or sent. Some unmarked sensitive content cannot be identified."
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Not now")
        if alert.runModal() == .alertFirstButtonReturn {
            editSettings {
                $0.consent = true
                $0.automatic = true
            }
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
        add("Check for Updates…", #selector(checkForUpdates), enabled: !updates.busy)
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
        editSettings { $0.automatic.toggle() }
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
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = SettingsView(preferences: preferences, updates: updates)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Pink Settings"
        window.setContentSize(NSSize(width: 680, height: 680))
        window.contentMinSize = NSSize(width: 680, height: 680)
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
    @objc private func checkForUpdates() { updates.check() }
}
struct SettingsView: View {
    @ObservedObject var preferences: SettingsModel
    @State private var error = ""
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var section = SettingsSection.formats
    private enum SettingsSection: Hashable { case formats, general }
    let updates: UpdateController

    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings section", selection: $section) {
                Text("Link formats").tag(SettingsSection.formats)
                Text("General").tag(SettingsSection.general)
            }
            .pickerStyle(.segmented).labelsHidden()
            .frame(width: 260).padding(.vertical, 14)
            .accessibilityIdentifier("settings-section")

            // Keep each pane's draft and scroll position when switching sections.
            ZStack {
                LinkRulesView(preferences: preferences)
                    .scrollContentBackground(.hidden)
                    .opacity(section == .formats ? 1 : 0)
                    .disabled(section != .formats)
                    .allowsHitTesting(section == .formats)
                    .accessibilityHidden(section != .formats)
                generalSettings
                    .scrollContentBackground(.hidden)
                    .opacity(section == .general ? 1 : 0)
                    .disabled(section != .general)
                    .allowsHitTesting(section == .general)
                    .accessibilityHidden(section != .general)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .frame(minWidth: 680, minHeight: 680)
        .alert(
            "Couldn’t apply change",
            isPresented: Binding(
                get: { !error.isEmpty }, set: { if !$0 { error = "" } }
            )
        ) {
            Button("OK") { error = "" }
        } message: {
            Text(error)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginStatus = SMAppService.mainApp.status
        }
    }

    private var generalSettings: some View {
        Form {
            Section {
                Toggle(
                    "Format links automatically",
                    isOn: Binding(
                        get: { preferences.value.automatic },
                        set: { enabled in
                            do { try preferences.edit { $0.automatic = enabled } } catch {
                                self.error = "Your previous settings are still active. Try again."
                            }
                        }
                    )
                ).disabled(!preferences.value.consent)
                Text("Copy a link, then paste a shorter, clickable version. Plain-text paste keeps your original text.")
                    .font(.caption).foregroundStyle(.secondary)
                if !preferences.value.consent {
                    Text("Choose Enable automatic formatting in Pink’s menu to get started.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("General").font(.title2.bold())
            }
            Section("Link labels") {
                Toggle(
                    "Show link icons",
                    isOn: Binding(
                        get: { preferences.value.showLinkIcons },
                        set: { enabled in
                            do { try preferences.edit { $0.showLinkIcons = enabled } } catch {
                                self.error = "Your previous settings are still active. Try again."
                            }
                        }
                    ))
                Text("Add emoji to known links, including pull requests, issues, files, releases and tickets.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Copied rich text") {
                Toggle(
                    "Rewrite already-formatted URLs",
                    isOn: Binding(
                        get: { preferences.value.rewriteFormattedURLs },
                        set: { enabled in
                            do { try preferences.edit { $0.rewriteFormattedURLs = enabled } } catch {
                                self.error = "Your previous settings are still active. Try again."
                            }
                        }
                    ))
                Text(
                    "Also shorten raw URL links copied from browsers and chat. May simplify formatting. Messages with named links stay unchanged. Plain paste stays exact."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle(
                    "Open Pink at login",
                    isOn: Binding(
                        get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                        set: { enabled in
                            do {
                                if enabled {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch { self.error = "Couldn’t change login settings. Try again in System Settings." }
                            loginStatus = SMAppService.mainApp.status
                        }
                    ))
                if loginStatus == .requiresApproval {
                    Text("Allow Pink in Login Items to finish setting up.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Login Items Settings…") { SMAppService.openSystemSettingsLoginItems() }
            } header: {
                Text("Start with your Mac")
            }
            UpdatesSettings(updates: updates)
            Section("Private by design") {
                Label("Your clipboard stays on your Mac.", systemImage: "lock.shield")
                Text(
                    "No clipboard history, accounts or telemetry. Pink never intercepts your paste shortcut. An immediate paste may arrive before formatting finishes."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
}
