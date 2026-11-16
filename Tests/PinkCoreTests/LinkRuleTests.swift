import XCTest

@testable import PinkCore

final class LinkRuleTests: XCTestCase {
    private func jira(_ pattern: String = "https://jira.example/browse/{issue}") -> LinkRule {
        LinkRule(name: "Jira", urlPattern: pattern, labelTemplate: "{issue}")
    }

    func testCustomLinkAndProseKeepExactTargets() throws {
        let parser = try Parser(linkRules: [jira()])
        let url = "https://JIRA.EXAMPLE/browse/ACME-184273/?view=all&x=%2F#comment-2"
        let reference = try XCTUnwrap(parser.parse(url))
        XCTAssertEqual(reference.label, "ACME-184273")
        XCTAssertEqual(reference.original, url)
        XCTAssertTrue(reference.html.contains("view=all&amp;x=%2F"))
        let prose = "Review \(url) and https://github.com/acme/widget/issues/5 please"
        let formatted = try XCTUnwrap(parser.parseText(prose))
        XCTAssertEqual(formatted.original, prose)
        XCTAssertEqual(formatted.displayText, "Review ACME-184273 and acme/widget#5 please")
        XCTAssertEqual(parser.matches(url).first?.captures, ["issue": "ACME-184273"])
        XCTAssertEqual(parser.matches(url).first?.reference, reference)
    }

    func testRemainderEncodingPortsHTTPAndFullPathMatching() throws {
        let rule = LinkRule(
            name: "Docs", urlPattern: "https://docs.example:8443/docs/{path...}", labelTemplate: "Read {path}")
        let parser = try Parser(rules: [], linkRules: [rule, jira("http://jira.example/code/browse/{issue}")])
        let url = "https://docs.example:8443/docs/Équipe/Getting%20started.md#section"
        XCTAssertEqual(parser.parse(url)?.label, "Read Équipe/Getting started.md")
        XCTAssertEqual(parser.parse(url)?.original, url)
        XCTAssertEqual(parser.parse("http://jira.example/code/browse/ABC-1")?.label, "ABC-1")
        for invalid in [
            "https://docs.example/docs/guide", "https://docs.example:8443/docs", "https://docs.example:8443/docs/",
            "https://docs.example:8443/docset/guide", "https://docs.example:8443/docs/a%2Fb",
            "https://jira.example/code/browse/ABC-1", "http://jira.example/code/browse/ABC-1/extra",
            "http://jira.example/codex/browse/ABC-1", "http://jira.example/code/browse/ABC-1//",
        ] { XCTAssertNil(parser.parse(invalid), invalid) }
    }

    func testExplicitOverridesDisabledRulesAndOrdering() throws {
        let url = "https://github.com/acme/widget/issues/3"
        var first = LinkRule(
            name: "First", urlPattern: "https://github.com/{owner}/{repo}/issues/{number}",
            labelTemplate: "Issue {number}")
        var second = first
        second.id = UUID()
        second.name = "Second"
        second.labelTemplate = "#{number}"
        XCTAssertEqual(try Parser(linkRules: [first]).parse(url)?.label, "acme/widget#3")
        first.overridesBuiltIns = true
        second.overridesBuiltIns = true
        let parser = try Parser(linkRules: [first, second])
        XCTAssertEqual(parser.parse(url)?.label, "Issue 3")
        XCTAssertEqual(parser.matches(url).map(\.ruleName), ["First", "Second", "github.com preset"])
        XCTAssertEqual(try Parser(linkRules: [second, first]).parse(url)?.label, "#3")
        first.enabled = false
        XCTAssertEqual(
            try Parser(linkRules: [first, second]).matches(url).map(\.ruleName), ["Second", "github.com preset"])
        XCTAssertNil(try Parser(rules: [], linkRules: [first]).parse(url))
    }

    func testMalformedRulesFailBeforeTheyCanBeSaved() throws {
        for pattern in [
            "", "jira.example/browse/{issue}", "ftp://jira.example/browse/{issue}",
            "https://*.example/browse/{issue}", "https://{host}/browse/{issue}",
            "https://user:password@jira.example/browse/{issue}", "https://jira.example:/browse/{issue}",
            "https://jira.example:0/browse/{issue}", "https://jira.example:65536/browse/{issue}",
            "https://jira.example/browse/{issue}?x=1", "https://jira.example/browse/{issue}#fragment",
            "https://jira.example/browse/{issue}/{issue}", "https://jira.example/browse/{9issue}",
            "https://jira.example/browse/{issue...}/more", "https://jira.example/browse/{issue}/{other...}/{tail...}",
            "https://jira.example/browse/prefix-{issue}", "https://jira.example/browse/{issue",
            "https://jira.example//browse/{issue}", "https://jira.example/../browse/{issue}",
            "https://jira.example/browse/%2f/{issue}", "https://jira.example/browse/\\{issue}",
            "http://github.com/{issue}", "http://gitlab.com/{issue}",
        ] { XCTAssertThrowsError(try Parser(linkRules: [jira(pattern)]), pattern) }
        for template in ["", " ", "{unknown}", "{issue...}", "{issue", "issue}", "{issue}\n", "{issue}\u{202e}"] {
            var rule = jira()
            rule.labelTemplate = template
            XCTAssertThrowsError(try Parser(linkRules: [rule]), template)
        }
        var rule = jira()
        rule.name = "\n"
        XCTAssertThrowsError(try Parser(linkRules: [rule]))
        XCTAssertThrowsError(try Parser(linkRules: [jira(), jira()].map { _ in rule }))
        XCTAssertThrowsError(try Parser(linkRules: (0..<65).map { _ in jira() }))
        for template in LinkRule.templates { XCTAssertNoThrow(try Parser(linkRules: [template]), template.name) }
    }

    func testCustomRulesUseStrictURLValidationAndEscapeLabels() throws {
        var rule = jira()
        rule.labelTemplate = "<&'\" {issue}"
        let parser = try Parser(linkRules: [rule])
        XCTAssertEqual(
            parser.parse("https://jira.example/browse/A-1")?.html,
            "<a href=\"https://jira.example/browse/A-1\">&lt;&amp;&#39;&quot; A-1</a>")
        for input in [
            "https://jira.example.evil/browse/A-1", "https://user@jira.example/browse/A-1",
            "https://jira.example/browse/A-1?q=%xx", "https://jira.example/browse/A-1?q=%0a",
            "https://jira.example/browse/A%2f1", "https://jira.example/browse/%2e%2e",
            "https://jira.example/browse/A-1?q=%FF", "https://jira.example/browse/A-1?q=%E2%80%AE",
            "https://jira.example/browse/A-1\u{202e}", " https://jira.example/browse/A-1",
            "https://jira.example/browse/A-1/other", "http://jira.example/browse/A-1",
        ] { XCTAssertNil(parser.parse(input), input) }
    }

    func testProsePunctuationAndDotSegmentsAreNotCaptured() throws {
        let parser = try Parser(linkRules: [jira()])
        for suffix in [".", ",", ";", ":", "!"] {
            let text = "Review https://jira.example/browse/ACME-184273\(suffix)"
            XCTAssertEqual(parser.parseText(text)?.displayText, "Review ACME-184273\(suffix)")
        }
        let text = "Review https://jira.example/browse/ACME-184273."
        let formatted = try XCTUnwrap(parser.parseText(text))
        XCTAssertEqual(
            formatted.html,
            "<span style=\"white-space: pre-wrap\">Review <a href=\"https://jira.example/browse/ACME-184273\">ACME-184273</a>.</span>"
        )
        XCTAssertEqual(parser.parseText("Visit https://github.com/acme/widget.")?.displayText, "Visit acme/widget.")
        for url in [
            "https://github.com/acme/widget/..", "https://github.com/acme/widget/%2e", "https://jira.example/browse/..",
        ] {
            XCTAssertNil(parser.parseText("Visit \(url)"), url)
        }
    }

    @MainActor func testClipboardCustomLinkAndRestoreKeepOriginalRepresentations() async throws {
        let board = FakeBoard()
        let clock = Clock()
        let monitor = ClipboardMonitor(
            board: board, builder: Builder(), permission: Permission(), scheduler: clock,
            parser: try Parser(linkRules: [jira()]))
        monitor.enable()
        let url = "https://jira.example/browse/ACME-184273?x=%2F#comment-2"
        let payload = Payload([Types.text: Data(url.utf8), Types.url: Data(url.utf8)])
        board.external(payload)
        clock.tick?()
        XCTAssertEqual(board.writes, 1)
        XCTAssertEqual(board.payload.string(Types.text), url)
        XCTAssertEqual(board.payload.string(Types.html), "<a href=\"\(url)\">ACME-184273</a>")
        XCTAssertTrue(monitor.canRestore)
        clock.tick?()
        XCTAssertEqual(board.writes, 1)
        monitor.restore()
        XCTAssertEqual(board.payload, payload)
    }

    func testGitHubRepositoryFileAndReleasePresets() throws {
        let parser = try Parser()
        for (url, label) in [
            ("https://github.com/Acme/Widget/?x=%2F#readme", "Acme/Widget"),
            (
                "https://github.com/acme/widget/blob/main/Sources/App.swift#L10-L20",
                "acme/widget · main/Sources/App.swift:10–20"
            ),
            ("https://github.com/acme/widget/blob/main/Read%20me.md#L5", "acme/widget · main/Read me.md:5"),
            (
                "https://github.com/acme/widget/blob/feature/topic/Sources/App.swift",
                "acme/widget · feature/topic/Sources/App.swift"
            ),
            ("https://github.com/acme/widget/releases/tag/v1.2.3", "acme/widget@v1.2.3"),
            ("https://github.com/acme/widget/releases/tag/releases/v2/", "acme/widget@releases/v2"),
        ] {
            let reference = try XCTUnwrap(parser.parse(url), url)
            XCTAssertEqual(reference.label, label)
            XCTAssertEqual(reference.original, url)
        }
        for invalid in [
            "https://github.com/acme", "https://github.com/settings/profile", "https://github.com/orgs/acme",
            "https://github.com/acme/widget/tree/main", "https://github.com/acme/widget/blob/main",
            "https://github.com/acme/widget/releases", "https://github.com/acme/widget/releases/latest",
            "https://github.com/acme/widget/releases/tag", "https://github.com/acme/widget/blob/main/../file",
        ] { XCTAssertNil(parser.parse(invalid), invalid) }
        let enterprise = try Parser(rules: [.init(service: .github, host: "code.example", basePath: "/git")])
        XCTAssertEqual(enterprise.parse("https://code.example/git/acme/widget")?.label, "acme/widget")
    }

    func testSettingsMigrationAndRuleRoundTrip() throws {
        let old = Data(
            #"{"schema":1,"consent":true,"automatic":true,"rules":[{"service":"gitlab","host":"code.example","basePath":"/git","enabled":false,"allowHTTP":true}]}"#
                .utf8)
        var settings = try Settings.decode(old)
        XCTAssertTrue(settings.consent)
        XCTAssertTrue(settings.automatic)
        XCTAssertEqual(
            settings.rules,
            [.init(service: .gitlab, host: "code.example", basePath: "/git", enabled: false, allowHTTP: true)])
        XCTAssertEqual(settings.linkRules, [])
        settings.linkRules = [jira()]
        XCTAssertEqual(try Settings.decode(JSONEncoder().encode(settings)), settings)
        settings.linkRules[0].labelTemplate = "{missing}"
        XCTAssertThrowsError(try Settings.decode(JSONEncoder().encode(settings)))
    }
}
