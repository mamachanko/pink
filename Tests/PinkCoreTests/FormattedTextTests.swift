import XCTest

@testable import PinkCore

final class FormattedTextTests: XCTestCase {
    private let github = "https://github.com/Acme/Widget/pull/123"
    private let gitlab = "https://gitlab.com/Group/Sub/Repo/-/merge_requests/45"

    func testPositionsDuplicatesWhitespaceAndNestedDelimiters() throws {
        let parser = try Parser()
        for (input, expected) in [
            (github, "Acme/Widget#123"),
            ("\(github) first", "Acme/Widget#123 first"),
            ("review \(github)", "review Acme/Widget#123"),
            ("review \(github) now", "review Acme/Widget#123 now"),
            ("💕 ((\(github))), [\(gitlab)].", "💕 ((Acme/Widget#123)), [Group/Sub/Repo!45]."),
            ("'\(github)' and “\(gitlab)”", "'Acme/Widget#123' and “Group/Sub/Repo!45”"),
            ("  \(github)\t\r\n\(github)\r\(gitlab)  ", "  Acme/Widget#123\t\r\nAcme/Widget#123\rGroup/Sub/Repo!45  "),
        ] {
            let text = try XCTUnwrap(parser.parseText(input), input)
            XCTAssertEqual(text.original, input)
            XCTAssertEqual(text.displayText, expected)
            XCTAssertEqual(
                text.parts.map {
                    switch $0 {
                    case .text(let value): value
                    case .reference(let reference): reference.original
                    }
                }.joined(), input)
        }
        XCTAssertEqual(parser.parseText(github)?.singleReference?.original, github)
        XCTAssertNil(parser.parseText(" \(github)")?.singleReference)
        XCTAssertNil(parser.parseText("\(github) \(gitlab)")?.singleReference)
    }

    func testExactQueriesFragmentsCaseAndEnterpriseRules() throws {
        let parser = try Parser(
            rules: HostRule.defaults + [
                .init(service: .gitlab, host: "git.example", port: 8443, basePath: "/code", allowHTTP: true)
            ])
        for url in [
            github + "/files/?x=a&y=b#review",
            "https://GITHUB.COM/%41cme/Widget/issues/0000123?x=%2F#Upper",
            gitlab + "/diffs?x=(a)#note",
            "http://git.example:8443/code/Team/Nested/Project/-/issues/2",
            github + "?x=keep.,;:!?'#fragment!",
        ] {
            let text = try XCTUnwrap(parser.parseText("Review (\(url)) please"), url)
            let references = text.parts.compactMap { part -> Reference? in
                if case .reference(let reference) = part { return reference }
                return nil
            }
            XCTAssertEqual(references.map(\.original), [url])
            XCTAssertEqual(text.original, "Review (\(url)) please")
        }
        XCTAssertNil(parser.parseText("https://git.example:8443/codex/a/b/-/issues/2"))
    }

    func testUnsupportedAndMaliciousTokensStayUnchanged() throws {
        let parser = try Parser()
        for invalid in [
            "https://github.com.evil/a/b/pull/1", "https://user@github.com/a/b/pull/1",
            "https://github.com/a/b/pull/0", "https://github.com/a%2fb/b/pull/1",
            "https://github.com/a/b/pull/1/unsupported", "https://github.com/a/b/pull/1?x=%xx",
            "https://github.com/a/b/pull/1?x=%0A", "https://github.com/a/b/pull/1?x=%E2%80%AE",
            "https://evil.example/?next=\(github)", "ftp://github.com/a/b/pull/1",
            "javascript:\(github)", "mailto:\(github)",
            "word\(github)", "x-\(github)", "/\(github)", "@\(github)",
            "[named](\(github))", "`\(github)`",
        ] {
            XCTAssertNil(parser.parseText("Review \(invalid) please"), invalid)
            let input = "\(invalid) plus \(gitlab)"
            let text = try XCTUnwrap(parser.parseText(input), invalid)
            XCTAssertEqual(text.displayText, "\(invalid) plus Group/Sub/Repo!45")
            XCTAssertEqual(text.original, input)
        }
    }

    func testDocumentSafetyAndBounds() throws {
        let parser = try Parser()
        for control in ["\u{0}", "\u{1b}", "\u{7f}", "\u{85}", "\u{202e}", "\u{2066}", "\u{200f}"] {
            XCTAssertNil(parser.parseText("Before\(control) \(github)"))
        }
        XCTAssertNil(parser.parseText("no supported links"))
        XCTAssertNil(parser.parseText("<a href=\"\(github)\">named</a>"))
        XCTAssertNil(parser.parseText(String(repeating: "💕", count: 2048) + github))
        let boundary = String(repeating: "x", count: 8192 - github.utf8.count - 1) + " " + github
        XCTAssertNotNil(parser.parseText(boundary))
        XCTAssertNil(parser.parseText(boundary + "x"))
        let pathological = "Review " + github + String(repeating: ")", count: 1000)
        XCTAssertNil(parser.parseText(pathological))
        XCTAssertEqual(parser.parseText(pathological + " " + gitlab)?.displayText, pathological + " Group/Sub/Repo!45")
        let disabled = try Parser(rules: [.init(service: .github, host: "github.com", enabled: false)])
        XCTAssertNil(disabled.parseText("Review \(github)"))
    }

    func testHTMLEscapingAndParagraphs() throws {
        let url = github + "?x=a&y='q'#note"
        let input = "A & B < 2 \"quoted\"\r\n\t\(url)\nEnd"
        let text = try XCTUnwrap(Parser().parseText(input))
        XCTAssertEqual(
            text.html,
            "<span style=\"white-space: pre-wrap\">A &amp; B &lt; 2 &quot;quoted&quot;<br>\t<a href=\"https://github.com/Acme/Widget/pull/123?x=a&amp;y=&#39;q&#39;#note\">Acme/Widget#123</a><br>End</span>"
        )
        XCTAssertEqual(text.original, input)
    }
}
