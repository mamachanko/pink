import XCTest

@testable import PinkCore

final class SettingsSessionTests: XCTestCase {
    @MainActor func testResetPublishesDefaultsOnlyAfterPersistenceSucceeds() async throws {
        var initial = Settings()
        initial.consent = true
        initial.automatic = true
        initial.showLinkIcons = false
        initial.rewriteFormattedURLs = true
        initial.rules = [HostRule(service: .gitlab, host: "git.example")]
        initial.linkRules = [LinkRule.templates[0]]
        enum SaveError: Error { case unavailable }
        var canSave = false
        var saved: Settings?
        let session = try SettingsSession(initial: initial) { value in
            if !canSave { throw SaveError.unavailable }
            saved = value
        }
        var observed: [(Settings, Settings)] = []
        session.onChange = { observed.append(($0, $1)) }
        XCTAssertThrowsError(try session.reset())
        XCTAssertEqual(session.value, initial)
        XCTAssertTrue(observed.isEmpty)
        canSave = true
        try session.reset()
        XCTAssertEqual(session.value, Settings())
        XCTAssertEqual(saved, Settings())
        XCTAssertEqual(observed.count, 1)
        XCTAssertEqual(observed.first?.0, initial)
        XCTAssertEqual(observed.first?.1, Settings())
    }

    @MainActor func testEditsFromDifferentSurfacesKeepLatestValues() async throws {
        var initial = Settings()
        initial.consent = true
        initial.automatic = true
        initial.rewriteFormattedURLs = true
        initial.rules.append(HostRule(service: .gitlab, host: "git.example", basePath: "/team"))
        var saved: [Settings] = []
        let session = try SettingsSession(initial: initial) { saved.append($0) }
        var observed: [(Settings, Settings)] = []
        session.onChange = { observed.append(($0, $1)) }

        // Pause from the menu while Settings is open, then add a format from its editor.
        try session.edit { $0.automatic = false }
        let format = LinkRule.templates[0]
        try session.edit { $0.linkRules.append(format) }
        XCTAssertFalse(session.value.automatic)
        XCTAssertEqual(session.value.linkRules, [format])
        XCTAssertEqual(session.value.rules, initial.rules)
        XCTAssertTrue(session.value.rewriteFormattedURLs)
        XCTAssertTrue(session.value.consent)
        XCTAssertEqual(saved.last, session.value)
        XCTAssertEqual(observed.count, 2)
        XCTAssertTrue(observed[0].0.automatic)
        XCTAssertFalse(observed[0].1.automatic)
        XCTAssertFalse(observed[1].0.automatic)
        XCTAssertFalse(observed[1].1.automatic)

        // A menu edit must also preserve a format saved in Settings.
        try session.edit { $0.automatic = true }
        XCTAssertEqual(session.value.linkRules, [format])
        XCTAssertTrue(session.value.automatic)
    }

    @MainActor func testFailedSaveDoesNotPublishOrApplyDraft() async throws {
        enum SaveError: Error { case unavailable }
        let initial = Settings()
        var canSave = false
        var saves = 0
        let session = try SettingsSession(initial: initial) { _ in
            saves += 1
            if !canSave { throw SaveError.unavailable }
        }
        var notifications = 0
        session.onChange = { _, _ in notifications += 1 }
        let format = LinkRule.templates[0]
        XCTAssertThrowsError(try session.edit { $0.linkRules.append(format) })
        XCTAssertEqual(session.value, initial)
        XCTAssertEqual(notifications, 0)

        canSave = true
        try session.edit { $0.linkRules.append(format) }
        XCTAssertEqual(session.value.linkRules, [format])
        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(saves, 2)
    }

    @MainActor func testRejectedEditorMutationCannotLeakPartialChanges() async throws {
        enum EditError: Error { case stale }
        let initial = Settings()
        var saves = 0
        let session = try SettingsSession(initial: initial) { _ in saves += 1 }
        var notifications = 0
        session.onChange = { _, _ in notifications += 1 }

        // An editor can discover a conflict after starting to construct its update.
        XCTAssertThrowsError(
            try session.edit {
                $0.rules.removeAll()
                $0.linkRules.append(LinkRule.templates[0])
                throw EditError.stale
            })
        XCTAssertEqual(session.value, initial)
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(notifications, 0)
    }

    @MainActor func testInvalidChangeAndNoOpNeverReachPersistence() async throws {
        let initial = Settings()
        var saves = 0
        let session = try SettingsSession(initial: initial) { _ in saves += 1 }
        var notifications = 0
        session.onChange = { _, _ in notifications += 1 }
        XCTAssertThrowsError(try session.edit { $0.schema = 2 })
        XCTAssertThrowsError(try session.edit { $0.rules.append($0.rules[0]) })
        XCTAssertThrowsError(
            try session.edit {
                $0.linkRules.append(LinkRule(name: "Broken", urlPattern: "https://", labelTemplate: "{missing}"))
            })
        try session.update(initial)
        XCTAssertEqual(session.value, initial)
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(notifications, 0)
    }
}
