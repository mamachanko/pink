import AppKit
import Combine
import PinkCore
import PinkPlatform
import Sparkle
import SwiftUI

@MainActor final class UpdateController: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var status = "Checks run only when you ask."
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    var onChange: (() -> Void)?
    private var sparkle: SPUStandardUpdaterController?
    private var observation: AnyCancellable?
    private var session: UpdateCheckSession?

    func check() {
        guard !busy else { return }
        NSApp.activate(ignoringOtherApps: true)
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        if Data(base64Encoded: key)?.count == 32 {
            if sparkle == nil {
                let controller = SPUStandardUpdaterController(
                    startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
                sparkle = controller
                observation = controller.updater.publisher(for: \.canCheckForUpdates)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] enabled in
                        MainActor.assumeIsolated {
                            self?.busy = !enabled
                            self?.onChange?()
                        }
                    }
                controller.startUpdater()
                // This user action requests a check, never unattended installation.
                controller.updater.automaticallyChecksForUpdates = false
                controller.updater.automaticallyDownloadsUpdates = false
            }
            sparkle?.checkForUpdates(nil)
            return
        }
        guard let current = ReleaseVersion(version) else {
            status = "This development build has no release version."
            return
        }
        let check = UpdateCheckSession(current: current, checker: GitHubReleaseChecker())
        session = check
        check.onChange = { [weak self, weak check] in
            guard let self, let check else { return }
            self.busy = check.state == .checking
            self.onChange?()
            switch check.state {
            case .idle: break
            case .checking: self.status = "Checking for updates…"
            case .current:
                self.status = "Pink is up to date."
                self.showResult(
                    title: "You’re up to date", message: "Pink \(self.version) is the latest available version.")
            case .available(let offer):
                self.status = "Pink \(offer.version.string) is available."
                self.showResult(
                    title: "Pink \(offer.version.string) is available",
                    message:
                        "You’re using Pink \(self.version). This build uses manual updates. Download the new version and replace Pink in Applications. If installed with Homebrew, use brew upgrade --cask mamachanko/pink/pink.",
                    page: offer.page)
            case .failed:
                self.status = "Couldn’t check for updates. Try again."
                self.showResult(
                    title: "Couldn’t check for updates",
                    message:
                        "Check your connection and try again. GitHub may temporarily limit update requests. You can also view releases in your browser.",
                    page: URL(string: "https://github.com/mamachanko/pink/releases/latest"))
            }
        }
        check.check()
    }
    func stop() { session?.cancel() }
    private func showResult(title: String, message: String, page: URL? = nil) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: page == nil ? "OK" : "View Release…")
        if page != nil { alert.addButton(withTitle: "Later") }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, let page { NSWorkspace.shared.open(page) }
    }
}

struct UpdatesSettings: View {
    @ObservedObject var updates: UpdateController
    var body: some View {
        Section("Updates") {
            HStack {
                Text("Pink \(updates.version)")
                Spacer()
                if updates.busy { ProgressView().controlSize(.small) }
                Button("Check for Updates…") { updates.check() }.disabled(updates.busy)
            }
            Text(updates.status).font(.caption).foregroundStyle(.secondary)
            Text("Checking contacts GitHub. Clipboard contents are never sent. Installation requires confirmation.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
