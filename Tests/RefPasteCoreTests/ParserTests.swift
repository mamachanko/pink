import XCTest

@testable import RefPasteCore

final class ParserTests: XCTestCase {
    func testRoutesAndExactPreservation() throws {
        let parser = try Parser()
        for (route, label) in [
            ("https://github.com/Acme/Widget/pull/00123/files/?x=1&y=2#hello", "Acme/Widget#00123"),
            ("https://gitlab.com/Group/Sub/Repo/-/merge_requests/2/pipelines", "Group/Sub/Repo!2"),
            ("https://gitlab.com/a/b/-/issues/3", "a/b#3"),
            ("https://GITHUB.COM/a/b/issues/9999999999999999999999999999", "a/b#9999999999999999999999999999"),
        ] {
            let result = try XCTUnwrap(parser.parse(route))
            XCTAssertEqual(result.original, route)
            XCTAssertEqual(result.label, label)
            XCTAssertTrue(result.html.contains("href=\""))
            XCTAssertFalse(result.html.contains("&y="))
        }
        for suffix in ["", "/", "/files", "/commits", "/checks"] {
            XCTAssertNotNil(parser.parse("https://github.com/a/b/pull/1" + suffix))
        }
    }
    func testRejectsMaliciousInputs() throws {
        let parser = try Parser()
        for input in [
            " https://github.com/a/b/pull/1", "https://github.com/a/b/pull/1\n", "http://github.com/a/b/pull/1",
            "https://github.com.evil/a/b/pull/1", "https://user@github.com/a/b/pull/1",
            "https://github.com/a%2fb/b/pull/1", "https://github.com/a/b/pull/0", "https://github.com/a/b/pull/١",
            "https://github.com/a/b/pull/1/no", "https://github.com/a/b/pull/1?q=%xx",
            "https://github.com/a/b/pull/1?q=%0a", "https://github.com:/a/b/pull/1",
            "[link](https://github.com/a/b/pull/1)", "https://github.com/a/b/pull/1\u{202e}",
            "https://github.com/a/b/pull/1 " + "https://github.com/a/b/pull/2", String(repeating: "a", count: 8193),
        ] { XCTAssertNil(parser.parse(input), input) }
    }
    func testEnterpriseRules() throws {
        let parser = try Parser(rules: [
            .init(service: .gitlab, host: "git.example", port: 8443, basePath: "/code", allowHTTP: true)
        ])
        XCTAssertEqual(parser.parse("http://git.example:8443/code/a/b/-/merge_requests/1")?.label, "a/b!1")
        XCTAssertNil(parser.parse("https://git.example:8443/codex/a/b/-/issues/1"))
        XCTAssertThrowsError(try Parser(rules: [.init(service: .github, host: "bad/path")]))
        XCTAssertThrowsError(
            try Parser(rules: [.init(service: .github, host: "x"), .init(service: .gitlab, host: "X", basePath: "/a")]))
        XCTAssertThrowsError(try Settings.decode(Data("{}".utf8)))
    }
}

extension ParserTests {
    func testEscapingAndEncodedControls() throws {
        let r = Reference(original: "https://github.com/a/b/pull/1?x='\"&y=<>", label: "a&<>'\"")
        XCTAssertEqual(
            r.html,
            "<a href=\"https://github.com/a/b/pull/1?x=&#39;&quot;&amp;y=&lt;&gt;\">a&amp;&lt;&gt;&#39;&quot;</a>")
        let p = try Parser()
        XCTAssertNil(p.parse("https://github.com/a/b/pull/1?q=%E2%80%AE"))
        XCTAssertNil(p.parse("https://github.com/a/b/pull/1?q=%FF"))
        XCTAssertNil(p.parse("https://gitlab.com/a/b/-/issues/1/diffs"))
        XCTAssertThrowsError(try Parser(rules: [.init(service: .github, host: "github.com", allowHTTP: true)]))
        XCTAssertThrowsError(try Parser(rules: [.init(service: .gitlab, host: "git.example", port: 0)]))
        XCTAssertThrowsError(try Parser(rules: [.init(service: .gitlab, host: "git.example", basePath: "/a//b")]))
    }
}
