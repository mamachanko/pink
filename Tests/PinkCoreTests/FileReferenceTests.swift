import XCTest

@testable import PinkCore

final class FileReferenceTests: XCTestCase {
    private let sha = "0123456789abcdef0123456789abcdef01234567"

    func testPublicFilesPermalinksAndLineRangesPreserveTheirExactDestinations() throws {
        let parser = try Parser()
        for (url, label) in [
            (
                "https://github.com/acme/widget/blob/\(sha)/Sources/App.swift?plain=1#L10-L20",
                "acme/widget · 01234567/Sources/App.swift:10–20"
            ),
            ("https://github.com/acme/widget/blob/main/Read%20me.md#L5", "acme/widget · main/Read me.md:5"),
            (
                "https://gitlab.com/team/sub/widget/-/blob/\(sha)/Sources/App.swift?ref_type=heads#L10-20",
                "team/sub/widget · 01234567/Sources/App.swift:10–20"
            ),
            ("https://gitlab.com/team/widget/-/blob/main/Read%20me.md#L5", "team/widget · main/Read me.md:5"),
            (
                "https://gitlab.com/team/widget/-/blob/feature/topic/App.swift#L5-L8",
                "team/widget · feature/topic/App.swift:5–8"
            ),
        ] {
            let reference = try XCTUnwrap(parser.parse(url), url)
            XCTAssertEqual(reference.label, label)
            XCTAssertEqual(reference.original, url)
        }
    }

    func testEnterpriseInstallationsUseTheSameFileFormats() throws {
        let parser = try Parser(rules: [
            .init(service: .github, host: "github.example", port: 8443, basePath: "/code"),
            .init(service: .gitlab, host: "gitlab.example", basePath: "/git"),
        ])
        let github = "https://github.example:8443/code/acme/widget/blob/\(sha)/App.swift#L2-L4"
        let gitlab = "https://gitlab.example/git/team/sub/widget/-/blob/\(sha)/App.swift#L2-4"
        XCTAssertEqual(parser.parse(github)?.label, "acme/widget · 01234567/App.swift:2–4")
        XCTAssertEqual(parser.parse(gitlab)?.label, "team/sub/widget · 01234567/App.swift:2–4")
        XCTAssertEqual(parser.parse(github)?.original, github)
        XCTAssertEqual(parser.parse(gitlab)?.original, gitlab)
        for url in [
            github.replacingOccurrences(of: "/code/", with: "/codex/"),
            github.replacingOccurrences(of: ":8443", with: ""),
            gitlab.replacingOccurrences(of: "gitlab.example", with: "gitlab.example.evil"),
        ] { XCTAssertNil(parser.parse(url)) }
    }

    func testOnlyFullHexRevisionsAreAbbreviatedAndBranchesStayOpaque() throws {
        let parser = try Parser()
        for revision in ["main", "feature/topic", "v1.2.3", "0123456789abc", String(repeating: "g", count: 40)] {
            let url = "https://github.com/acme/widget/blob/\(revision)/App.swift"
            XCTAssertEqual(parser.parse(url)?.label, "acme/widget · \(revision)/App.swift")
        }
        let sha256 = String(repeating: "A1", count: 32)
        XCTAssertEqual(
            parser.parse("https://gitlab.com/team/widget/-/blob/\(sha256)/App.swift")?.label,
            "team/widget · A1A1A1A1/App.swift")
    }

    func testLineNumbersArePositiveOrderedASCIIAndBoundedByInputRatherThanIntegerSize() throws {
        let parser = try Parser()
        for root in [
            "https://github.com/acme/widget/blob/main/App.swift",
            "https://gitlab.com/team/widget/-/blob/main/App.swift",
        ] {
            let base = try XCTUnwrap(parser.parse(root)).label
            for fragment in ["L0", "L0-L2", "L20-L10", "L2-L0", "L١", "L1-L٢", "L1-", "L1-L2-extra", "section"] {
                let url = root + "#" + fragment
                XCTAssertEqual(parser.parse(url)?.label, base, fragment)
                XCTAssertEqual(parser.parse(url)?.original, url)
            }
            let huge = String(repeating: "9", count: 30)
            XCTAssertEqual(parser.parse(root + "#L2-L" + huge)?.label, base + ":2–" + huge)
        }
        XCTAssertEqual(
            parser.parse("https://github.com/acme/widget/blob/main/App.swift#L02-L010")?.label,
            "acme/widget · main/App.swift:02–010")
    }

    func testFreshAndDecodedDefaultsEnableEveryGitHubKindWithoutCustomRules() throws {
        let settings = Settings()
        for value in [settings, try Settings.decode(JSONEncoder().encode(settings))] {
            XCTAssertTrue(value.linkRules.isEmpty)
            let parser = try Parser(rules: value.rules, linkRules: value.linkRules)
            for path in [
                "acme/widget", "acme/widget/issues/1", "acme/widget/pull/2",
                "acme/widget/blob/main/App.swift#L2", "acme/widget/blob/\(sha)/App.swift#L2-L4",
                "acme/widget/releases/tag/v1.0",
            ] {
                XCTAssertNotNil(parser.parse("https://github.com/" + path), path)
            }
        }
        var disabled = settings
        disabled.rules[0].enabled = false
        let decoded = try Settings.decode(JSONEncoder().encode(disabled))
        XCTAssertEqual(decoded.rules, disabled.rules)
        XCTAssertNil(try Parser(rules: decoded.rules).parse("https://github.com/acme/widget/blob/main/App.swift#L2"))
    }

    func testUnsupportedOrUnsafeFileRoutesStayUnmatched() throws {
        let parser = try Parser()
        for url in [
            "https://gitlab.com/team/widget/-/blob/main", "https://gitlab.com/team/widget/-/tree/main/App.swift",
            "https://gitlab.com/team/widget/-/raw/main/App.swift", "https://gitlab.com/team/widget/-/blob/main/..",
            "https://gitlab.com/team/widget/-/blob/main/a%2Fb", "http://gitlab.com/team/widget/-/blob/main/App.swift",
            "https://user@github.com/acme/widget/blob/main/App.swift",
            "https://github.com/acme/widget/blob/main/App.swift#L2%0A",
        ] { XCTAssertNil(parser.parse(url), url) }
    }
}
