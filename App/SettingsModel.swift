import Combine
import PinkCore
import SwiftUI

@MainActor final class SettingsModel: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private let session: SettingsSession
    var value: PinkCore.Settings { session.value }
    var onChange: ((PinkCore.Settings, PinkCore.Settings) -> Void)?

    init(initial: PinkCore.Settings, persist: @escaping (PinkCore.Settings) throws -> Void) throws {
        session = try SettingsSession(initial: initial, persist: persist)
        session.onChange = { [weak self] previous, current in
            self?.objectWillChange.send()
            self?.onChange?(previous, current)
        }
    }

    func edit(_ change: (inout PinkCore.Settings) throws -> Void) throws {
        try session.edit(change)
    }
}
