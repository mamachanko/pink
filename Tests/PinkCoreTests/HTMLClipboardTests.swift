import Foundation
import XCTest

@testable import PinkCore

final class HTMLClipboardTests: XCTestCase {
    private let url = "https://github.com/Acme/Widget/pull/123?x=a&b=%2F#review"
    private func links(_ html: String, _ plain: String) -> [SourceLink]? {
        HTMLClipboard.rawLinks(in: Data(html.utf8), matching: plain)
    }
    func testBrowserFragmentEntitiesAndUTF16Ranges() throws {
        let escaped = url.replacingOccurrences(of: "&", with: "&amp;")
        let plain = "💕 Équipe e\u{301}: \(url) & thanks"
        let html =
            "\u{FEFF}<!DOCTYPE html><HTML><head><meta charset='utf-8'></head><body><!--StartFragment--><b>💕 Équipe e&#769;: <A HREF='\(escaped)' style='color:blue'>\(escaped)</a> &amp; thanks</b><!--EndFragment--></body></HTML>"
        let result = try XCTUnwrap(links(html, plain))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].range, (plain as NSString).range(of: url))
        XCTAssertEqual(result[0].target, url)
    }
    func testLayoutWhitespaceMultipleRepeatedLinksAndWordBreaks() throws {
        let first = "https://github.com/a/b/issues/1"
        let second = "https://gitlab.com/team/sub/project/-/merge_requests/2"
        let plain = "Review  \(first)\n\nthen\t\(second) and \(first)."
        let html =
            "<div>Review&nbsp;<a href='\(first)'>https://github.com/<wbr>a/b/issues/1</a></div><p>then <a href='\(second)'>\(second)</a> and <a href='\(first)'>\(first)</a>.</p>"
        let result = try XCTUnwrap(links(html, plain))
        XCTAssertEqual(result.map(\.target), [first, second, first])
        for link in result { XCTAssertEqual((plain as NSString).substring(with: link.range), link.target) }
        XCTAssertNotNil(links("<span>Review \(first)</span>", "Review \(first)"))
    }
    func testNamedLinksConflictingTargetsAndDifferentTextAreRejected() {
        for html in [
            "<a href='\(url.replacingOccurrences(of: "&", with: "&amp;"))'>Review</a>",
            "<a href='https://github.com/other/repo/pull/2'>\(url.replacingOccurrences(of: "&", with: "&amp;"))</a>",
            "<a href='https://github.com/a/b/issues/1'>https://github.com/a/b/issues/1</a> extra words",
            "<a href='https://github.com/a/b/issues/1'><a href='https://example.com'>https://example.com</a></a>",
        ] { XCTAssertNil(links(html, url)) }
        XCTAssertNil(links("<span>ab</span>", "a b"))
        XCTAssertNil(
            links(
                "<a href='https://example.com'>named</a> https://github.com/a/b/issues/1",
                "named https://github.com/a/b/issues/1"))
    }
    func testNoActiveElementsResourcesDTDOrAmbiguousAttributes() {
        let plain = "https://github.com/a/b/issues/1"
        for prefix in [
            "<script>alert(1)</script>", "<img src='https://example.invalid/tracker'>", "<iframe></iframe>",
            "<object></object>", "<svg></svg>", "<style>body{display:none}</style>",
            "<!DOCTYPE html SYSTEM 'file:///etc/passwd'>",
            "<!DOCTYPE html [<!ENTITY x SYSTEM 'https://example.invalid'>]>",
            "<?xml version='1.0'?>", "<meta http-equiv='refresh' content='0;url=https://example.invalid'>",
        ] { XCTAssertNil(links(prefix + plain, plain)) }
        for html in [
            "<span onclick='alert(1)'>\(plain)</span>", "<span src='https://example.invalid'>\(plain)</span>",
            "<a href='\(plain)' HREF='https://example.invalid'>\(plain)</a>",
            "<a href='javascript:alert(1)'>javascript:alert(1)</a>",
            "<a href='https://user:password@example.invalid'>https://user:password@example.invalid</a>",
            "<a href='/relative'>/relative</a>", "<a href=\(plain)>\(plain)</a>",
        ] { XCTAssertNil(links(html, plain)) }
        // Presentational CSS is discarded, never interpreted or fetched.
        XCTAssertNotNil(
            links("<span style='background-image:url(https://example.invalid/tracker)'>\(plain)</span>", plain))
    }
    func testMalformedUnsupportedAndBoundedInputsFailSafely() {
        for html in [
            "<span>text", "<span>text</b>", "<!-- unclosed", "<a href='broken>", "<span>&unknown;</span>",
            "<custom>text</custom>", "<span:other>text</span:other>",
        ] {
            XCTAssertNil(links(html, "text"))
        }
        XCTAssertNil(HTMLClipboard.rawLinks(in: Data([0xFF]), matching: "text"))
        XCTAssertNil(links(String(repeating: " ", count: 65537), "text"))
        XCTAssertNil(links("text", String(repeating: "x", count: 8193)))
        XCTAssertNil(
            links(String(repeating: "<span>", count: 65) + "text" + String(repeating: "</span>", count: 65), "text"))
        XCTAssertNil(links("<span>" + String(repeating: "x", count: 32769) + "</span>", "text"))
    }
    func testPreferenceMigrationDefaultRoundTripAndInvalidValue() throws {
        var settings = Settings()
        settings.consent = true
        settings.automatic = true
        XCTAssertFalse(settings.rewriteFormattedURLs)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        object.removeValue(forKey: "rewriteFormattedURLs")
        let migrated = try Settings.decode(JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(migrated.rewriteFormattedURLs)
        XCTAssertTrue(migrated.consent)
        XCTAssertTrue(migrated.automatic)
        settings.rewriteFormattedURLs = true
        XCTAssertTrue(try Settings.decode(JSONEncoder().encode(settings)).rewriteFormattedURLs)
        object["rewriteFormattedURLs"] = "true"
        XCTAssertThrowsError(try Settings.decode(JSONSerialization.data(withJSONObject: object)))
    }
}
