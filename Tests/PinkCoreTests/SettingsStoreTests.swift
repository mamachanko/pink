import Foundation
import XCTest

@testable import PinkCore

final class SettingsStoreTests: XCTestCase {
    @MainActor func testMigrationIsValidatedAndDoesNotOverwritePinkSettings() async throws {
        let name = "Pink.tests.\(UUID())"
        let legacyName = "Pink.tests.legacy.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer {
            defaults.removePersistentDomain(forName: name)
            defaults.removePersistentDomain(forName: legacyName)
        }
        var previous = Settings()
        previous.consent = true
        previous.automatic = true
        previous.rules.append(.init(service: .gitlab, host: "git.example", basePath: "/code"))
        defaults.setPersistentDomain([SettingsStore.key: try JSONEncoder().encode(previous)], forName: legacyName)
        let store = SettingsStore(defaults: defaults, legacyDomain: legacyName)
        XCTAssertEqual(try store.load(), previous)
        XCTAssertEqual(try Settings.decode(XCTUnwrap(defaults.data(forKey: SettingsStore.key))), previous)
        let current = Settings()
        try store.save(current)
        XCTAssertEqual(try store.load(), current)
        // Invalid current settings fail safely; migration must not revive old consent.
        defaults.set(Data("{}".utf8), forKey: SettingsStore.key)
        XCTAssertThrowsError(try store.load())
        defaults.set("invalid", forKey: SettingsStore.key)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(defaults.string(forKey: SettingsStore.key), "invalid")
    }

    @MainActor func testInvalidLegacySettingsAreNotImported() async throws {
        let name = "Pink.tests.\(UUID())"
        let legacyName = "Pink.tests.legacy.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer {
            defaults.removePersistentDomain(forName: name)
            defaults.removePersistentDomain(forName: legacyName)
        }
        let store = SettingsStore(defaults: defaults, legacyDomain: legacyName)
        XCTAssertEqual(try store.load(), Settings())
        defaults.setPersistentDomain([SettingsStore.key: Data("{}".utf8)], forName: legacyName)
        XCTAssertThrowsError(try store.load())
        XCTAssertNil(defaults.data(forKey: SettingsStore.key))
    }
}
