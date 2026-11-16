import Foundation

/// A single, validated source of settings for every surface that can change them.
/// Failed persistence leaves the current settings and observers untouched.
@MainActor public final class SettingsSession {
    public private(set) var value: Settings
    public var onChange: ((_ previous: Settings, _ current: Settings) -> Void)?
    private let persist: (Settings) throws -> Void

    public init(initial: Settings, persist: @escaping (Settings) throws -> Void) throws {
        guard initial.schema == 1 else { throw ValidationError.invalidRules }
        _ = try Parser(rules: initial.rules, linkRules: initial.linkRules)
        value = initial
        self.persist = persist
    }

    public func update(_ next: Settings) throws {
        guard next != value else { return }
        guard next.schema == 1 else { throw ValidationError.invalidRules }
        _ = try Parser(rules: next.rules, linkRules: next.linkRules)
        try persist(next)
        let previous = value
        value = next
        onChange?(previous, next)
    }

    /// Derive an edit from the latest state, rather than a window's earlier snapshot.
    public func edit(_ change: (inout Settings) throws -> Void) throws {
        var next = value
        try change(&next)
        try update(next)
    }
}
