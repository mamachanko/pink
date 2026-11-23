import Combine
import PinkCore
import SwiftUI

@MainActor final class SettingsModel: ObservableObject {
    private let session: SettingsSession
    @Published private(set) var value: PinkCore.Settings
    var onChange: ((PinkCore.Settings, PinkCore.Settings) -> Void)?

    init(initial: PinkCore.Settings, persist: @escaping (PinkCore.Settings) throws -> Void) throws {
        session = try SettingsSession(initial: initial, persist: persist)
        value = initial
        session.onChange = { [weak self] previous, current in
            self?.value = current
            self?.onChange?(previous, current)
        }
    }

    func reset() throws {
        try session.reset()
    }

    func edit(_ change: (inout PinkCore.Settings) throws -> Void) throws {
        try session.edit(change)
    }
}
