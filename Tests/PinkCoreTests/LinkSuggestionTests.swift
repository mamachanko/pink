import XCTest

@testable import PinkCore

final class LinkSuggestionTests: XCTestCase {
    func testJiraFromOneExampleWorksForFutureTicketsWithoutPatternInput() throws {
        let input = "https://jira.example/browse/ACME-184273?view=all#comment-2"
        let suggestion = try LinkSuggestion(input)
        XCTAssertEqual(suggestion.parts, ["browse", "ACME-184273"])
        XCTAssertEqual(suggestion.defaultSelection, 1)
        XCTAssertFalse(suggestion.defaultIncludesContext)
        let rule = try suggestion.rule(selection: suggestion.defaultSelection, includeContext: false)
        XCTAssertEqual(rule.urlPattern, "https://jira.example/browse/{issue}")
        let parser = try Parser(linkRules: [rule])
        for url in [input, "https://jira.example/browse/OTHER-52/?x=%2F#different"] {
            let reference = try XCTUnwrap(parser.parse(url))
            XCTAssertEqual(reference.original, url)
            XCTAssertTrue(reference.label == "ACME-184273" || reference.label == "OTHER-52")
        }
        XCTAssertNil(parser.parse("https://jira.example.evil/browse/OTHER-52"))
        XCTAssertNil(parser.parse("https://jira.example/not-browse/OTHER-52"))
    }

    func testSelectionContextAndInstallationPrefix() throws {
        let suggestion = try LinkSuggestion("https://jira.example:8443/work/browse/ACME-1")
        let contextual = try suggestion.rule(selection: suggestion.defaultSelection, includeContext: true)
        XCTAssertEqual(try Parser(linkRules: [contextual]).parse(suggestion.original)?.label, "Jira · ACME-1")
        XCTAssertEqual(contextual.urlPattern, "https://jira.example:8443/work/browse/{issue}")
        let different = try suggestion.rule(selection: 0, includeContext: false)
        XCTAssertEqual(try Parser(linkRules: [different]).parse(suggestion.original)?.label, "work")
        XCTAssertThrowsError(try suggestion.rule(selection: -1, includeContext: false))
        XCTAssertThrowsError(try suggestion.rule(selection: nil, includeContext: false))
        XCTAssertThrowsError(try suggestion.rule(selection: 999, includeContext: false))
    }

    func testGitHubSuggestionsGeneralizeOwnersRepositoriesAndOpaquePaths() throws {
        for (example, future, expected) in [
            (
                "https://github.com/acme/widget/pull/123/files", "https://github.com/other/repo/pull/9/files",
                "other/repo#9"
            ),
            ("https://github.com/acme/widget/issues/123", "https://github.com/other/repo/issues/9", "other/repo#9"),
            ("https://github.com/acme/widget", "https://github.com/other/repo", "other/repo"),
            (
                "https://github.com/acme/widget/blob/feature/topic/App.swift",
                "https://github.com/other/repo/blob/main/Code.swift#L2", "other/repo · main/Code.swift"
            ),
            (
                "https://github.com/acme/widget/releases/tag/release/v1",
                "https://github.com/other/repo/releases/tag/releases/v2", "other/repo@releases/v2"
            ),
        ] {
            let suggestion = try LinkSuggestion(example)
            let rule = try suggestion.rule(
                selection: suggestion.defaultSelection, includeContext: suggestion.defaultIncludesContext)
            let parsed = try XCTUnwrap(Parser(rules: [], linkRules: [rule]).parse(future))
            XCTAssertEqual(parsed.original, future)
            XCTAssertEqual(parsed.label, expected)
        }
        let opaque = try LinkSuggestion("https://github.com/acme/widget/blob/feature/topic/App.swift")
        XCTAssertEqual(opaque.parts, ["acme", "widget", "blob", "feature/topic/App.swift"])
        let owner = try opaque.rule(selection: 0, includeContext: false)
        XCTAssertEqual(try Parser(rules: [], linkRules: [owner]).parse(opaque.original)?.label, "acme")
    }

    func testEncodedLiteralPathsUnicodeHTTPAndSiteRoots() throws {
        for input in [
            "https://docs.example/Getting%20started/Équipe/ABC-1?x=%2F#section",
            "https://docs.example/%47uide/ABC-1",
            "http://docs.example:8080/docs/ABC-1",
            "https://docs.example",
        ] {
            let suggestion = try LinkSuggestion(input)
            XCTAssertEqual(suggestion.usesHTTP, input.hasPrefix("http:"))
            let rule = try suggestion.rule(selection: suggestion.defaultSelection, includeContext: false)
            let reference = try XCTUnwrap(Parser(rules: [], linkRules: [rule]).parse(input))
            XCTAssertEqual(reference.original, input)
            XCTAssertEqual(reference.label, suggestion.parts.last ?? "docs.example")
        }
        let literal = LinkRule(
            name: "Guide", urlPattern: "https://docs.example/%47etting%20started/{id}", labelTemplate: "{id}")
        XCTAssertEqual(
            try Parser(linkRules: [literal]).parse("https://docs.example/Getting%20started/ABC-2")?.label, "ABC-2")
    }

    func testUnsafeOrUnrepresentableExamplesDoNotProduceUsableRules() throws {
        for input in [
            "", "not a link", "https://user:password@jira.example/browse/ABC-1", "ftp://jira.example/browse/ABC-1",
            "http://github.com/acme/widget", "https://jira.example/browse/..", "https://jira.example/browse/%2f",
            "https://jira.example/browse/ABC-1?q=%xx", "https://jira.example/browse/ABC-1?q=%0A",
            "https://jira.example/browse/ABC-1\u{202E}", "https://jira.example/browse/ABC-1?q=%FF",
            "https://docs.example/" + String(repeating: "a", count: 2100) + "/ABC-1",
        ] { XCTAssertThrowsError(try LinkSuggestion(input), input) }
        for pattern in [
            "https://%64ocs.example/{id}", "https://docs.example/%2f/{id}", "https://docs.example/%5c/{id}",
            "https://docs.example/%7bid%7d/{id}", "https://docs.example/%2e%2e/{id}",
            "https://docs.example/%xx/{id}", "https://docs.example/%0a/{id}", "https://docs.example/%FF/{id}",
        ] {
            XCTAssertThrowsError(
                try Parser(linkRules: [.init(name: "Bad", urlPattern: pattern, labelTemplate: "{id}")]), pattern)
        }
    }

    @MainActor func testOneSaveThenCopyAndRestoreWithRealSettingsSession() async throws {
        var persisted: Settings?
        let session = try SettingsSession(initial: Settings()) { persisted = $0 }
        let suggestion = try LinkSuggestion("https://jira.example/browse/ACME-184273")
        let rule = try suggestion.rule(selection: suggestion.defaultSelection, includeContext: false)
        try session.edit { $0.linkRules.insert(rule, at: 0) }
        XCTAssertEqual(persisted?.linkRules, [rule])
        let savedData = try JSONEncoder().encode(XCTUnwrap(persisted))
        XCTAssertFalse(String(decoding: savedData, as: UTF8.self).contains("ACME-184273"))
        let restored = try Settings.decode(savedData)
        let parser = try Parser(rules: restored.rules, linkRules: restored.linkRules)
        let board = FakeBoard()
        let clock = Clock()
        let monitor = ClipboardMonitor(
            board: board, builder: Builder(), permission: Permission(), scheduler: clock, parser: parser)
        monitor.enable()
        let text = "Review https://jira.example/browse/OTHER-99?view=all#comment please"
        let source = Payload([Types.text: Data(text.utf8)])
        board.external(source)
        clock.tick?()
        XCTAssertEqual(board.writes, 1)
        XCTAssertEqual(board.payload.string(Types.text), text)
        XCTAssertTrue(board.payload.string(Types.html)?.contains(">OTHER-99</a>") == true)
        monitor.restore()
        XCTAssertEqual(board.payload, source)
    }
}
