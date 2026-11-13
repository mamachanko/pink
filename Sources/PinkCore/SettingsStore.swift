import Foundation

/// Persists only validated settings. Clipboard data never enters this store.
@MainActor public struct SettingsStore {
    public static let key = "settings.v1"
    // Compatibility-only identifier; never used as Pink's current identity.
    public static let legacyDomainName = "io.refpaste.app"
    private let defaults: UserDefaults
    private let legacyDomain: String?

    public init(defaults: UserDefaults = .standard, legacyDomain: String? = legacyDomainName) {
        self.defaults = defaults
        self.legacyDomain = legacyDomain
    }

    public func load() throws -> Settings {
        if let current = defaults.object(forKey: Self.key) {
            guard let data = current as? Data else { throw ValidationError.invalidRules }
            return try Settings.decode(data)
        }
        guard let legacyDomain,
            let data = defaults.persistentDomain(forName: legacyDomain)?[Self.key] as? Data
        else {
            return Settings()
        }
        let settings = try Settings.decode(data)
        try save(settings)
        return settings
    }

    public func save(_ settings: Settings) throws {
        let data = try JSONEncoder().encode(settings)
        _ = try Settings.decode(data)
        defaults.set(data, forKey: Self.key)
    }
}
