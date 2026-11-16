import AppKit
import PinkCore
import XCTest

@testable import PinkPlatform

@MainActor private final class ObservedBoard: PasteboardPort {
    let native: NativeBoard
    var reads = 0
    var writes = 0
    var afterRead: (() -> Void)?
    init(_ board: NSPasteboard) { native = NativeBoard(board) }
    var changeCount: Int { native.changeCount }
    var advertisedTypes: [[String]] { native.advertisedTypes }
    func read() -> Payload? {
        reads += 1
        let value = native.read()
        afterRead?()
        return value
    }
    func readMarker() -> Data? { native.readMarker() }
    func write(_ payload: Payload) -> Bool {
        writes += 1
        return native.write(payload)
    }
}
@MainActor private struct HTMLPermission: PermissionPort { var canRead: Bool { true } }
@MainActor private final class HTMLScheduler: SchedulerPort {
    func start(_ tick: @escaping @MainActor () -> Void) {}
    func stop() {}
}

final class FormattedHTMLTests: XCTestCase {
    private let first = "https://github.com/Acme/Widget/pull/123?x=a&b=%2F#review"
    private let second = "https://gitlab.com/Group/Sub/Repo/-/merge_requests/45"
    private func html(_ url: String) -> String {
        let escaped = Reference.escape(url)
        return "<a href='\(escaped)'>\(escaped)</a>"
    }
    private func fixture() -> (String, Payload) {
        let plain = "💕 Review \(first)\nthen \(second)."
        return (
            plain,
            Payload([
                Types.text: Data(plain.utf8),
                Types.html: Data(
                    "<meta charset='utf-8'><div>💕 Review \(html(first))</div><div>then \(html(second)).</div>".utf8),
            ])
        )
    }
    @MainActor func testOptInMonitorBaselineOneItemSelfWriteAndExactRestoration() async throws {
        let board = NSPasteboard(name: .init("Pink.tests.\(UUID())"))
        defer { board.releaseGlobally() }
        let observed = ObservedBoard(board)
        let (plain, original) = fixture()
        let monitor = ClipboardMonitor(
            board: observed, builder: NativeRepresentations(), permission: HTMLPermission(),
            scheduler: HTMLScheduler(), parser: try Parser())
        monitor.enable()
        XCTAssertTrue(observed.native.write(original))
        monitor.tick()
        XCTAssertEqual(observed.writes, 0)
        XCTAssertFalse(monitor.canRestore)
        monitor.builder = NativeRepresentations(rewriteFormattedURLs: true)
        monitor.enable()
        monitor.tick()
        XCTAssertEqual(observed.writes, 0, "Changing a preference must not reformat the existing clipboard")
        XCTAssertTrue(observed.native.write(original))
        monitor.tick()
        XCTAssertEqual(observed.writes, 1)
        XCTAssertEqual(board.pasteboardItems?.count, 1)
        XCTAssertEqual(board.string(forType: .string), plain)
        XCTAssertNil(board.data(forType: .URL))
        let rich = try readRTF(XCTUnwrap(board.data(forType: .rtf)))
        XCTAssertEqual(rich.string, "💕 Review Acme/Widget#123\nthen Group/Sub/Repo!45.")
        var targets: [String] = []
        rich.enumerateAttribute(.link, in: NSRange(location: 0, length: rich.length)) { link, _, _ in
            if let link { targets.append(String(describing: link)) }
        }
        XCTAssertEqual(targets, [first, second])
        let count = board.changeCount
        monitor.tick()
        XCTAssertEqual(board.changeCount, count)
        XCTAssertEqual(observed.writes, 1)
        XCTAssertTrue(monitor.canRestore)
        monitor.restore()
        XCTAssertEqual(observed.native.read(), original)
        XCTAssertFalse(monitor.canRestore)
        XCTAssertTrue(observed.native.write(original))
        monitor.tick()
        XCTAssertTrue(monitor.canRestore)
        monitor.pause()
        XCTAssertFalse(monitor.canRestore)
        XCTAssertTrue(monitor.canRestore)
        monitor.tick()
        XCTAssertEqual(observed.writes, 1)
        monitor.restore()
        XCTAssertEqual(observed.native.read(), original)
        XCTAssertFalse(monitor.canRestore)
        XCTAssertTrue(observed.native.write(original))
        monitor.tick()
        XCTAssertEqual(observed.writes, 3, "An identical external copy must still be formatted")
        monitor.pause()
    }
    @MainActor func testHTMLAndRTFMustAgreeAndRetainValidatedStyles() async throws {
        let (plain, original) = fixture()
        var source = original
        let styled = NSMutableAttributedString(string: plain, attributes: [.font: NSFont.boldSystemFont(ofSize: 14)])
        for url in [first, second] { styled.addAttribute(.link, value: url, range: (plain as NSString).range(of: url)) }
        source.values[Types.rtf] = try rtf(styled)
        let builder = NativeRepresentations(rewriteFormattedURLs: true)
        let formatted = try XCTUnwrap(Parser().parseText(plain))
        let output = try XCTUnwrap(builder.build(formatted, source: source))
        let rich = try readRTF(XCTUnwrap(output.values[Types.rtf]))
        XCTAssertEqual(output.string(Types.text), plain)
        XCTAssertEqual(rich.string, formatted.displayText)
        for index in [0, rich.length - 1] {
            let font = try XCTUnwrap(rich.attribute(.font, at: index, effectiveRange: nil) as? NSFont)
            XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        }
        styled.addAttribute(.link, value: "https://example.invalid", range: (plain as NSString).range(of: first))
        source.values[Types.rtf] = try rtf(styled)
        XCTAssertNil(builder.build(formatted, source: source))
        source.values[Types.rtf] = try rtf(NSAttributedString(string: plain + " different"))
        XCTAssertNil(builder.build(formatted, source: source))
        let jira = "https://jira.example/browse/TEAM-123"
        let parser = try Parser(linkRules: [
            LinkRule(name: "Jira", urlPattern: "https://jira.example/browse/{issue}", labelTemplate: "{issue}")
        ])
        let custom = try XCTUnwrap(
            builder.build(
                try XCTUnwrap(parser.parseText(jira)),
                source: Payload([Types.text: Data(jira.utf8), Types.html: Data(html(jira).utf8)])))
        XCTAssertEqual(try readRTF(XCTUnwrap(custom.values[Types.rtf])).string, "TEAM-123")
    }
    @MainActor func testHTMLAndRTFStylesAgreeAndNamedLinksAreProtected() async throws {
        let (plain, source) = fixture()
        let styled = NSMutableAttributedString(string: plain, attributes: [.font: NSFont.boldSystemFont(ofSize: 14)])
        styled.addAttribute(.link, value: first, range: (plain as NSString).range(of: first))
        var combined = source
        combined.values[Types.rtf] = try rtf(styled)
        let builder = NativeRepresentations(rewriteFormattedURLs: true)
        let parsed = try XCTUnwrap(Parser().parseText(plain))
        let output = try XCTUnwrap(builder.build(parsed, source: combined))
        let rich = try readRTF(XCTUnwrap(output.values[Types.rtf]))
        for position in [0, rich.length - 1] {
            let font = try XCTUnwrap(rich.attribute(.font, at: position, effectiveRange: nil) as? NSFont)
            XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        }
        styled.addAttribute(.link, value: "https://example.invalid/named", range: NSRange(location: 0, length: 2))
        combined.values[Types.rtf] = try rtf(styled)
        XCTAssertTrue(builder.hasNamedLink(combined, original: plain))
        XCTAssertNil(builder.build(parsed, source: combined))
        for markup in [
            "<a href='https://example.invalid'>\(Reference.escape(plain))</a>",
            "<span>different text</span>", "<img src='https://example.invalid/tracker'>",
            "<a href='\(Reference.escape(first))'>Review</a> \(html(second))",
        ] {
            let payload = Payload([Types.text: Data(plain.utf8), Types.html: Data(markup.utf8)])
            XCTAssertTrue(builder.hasNamedLink(payload, original: plain))
            XCTAssertNil(builder.build(parsed, source: payload))
        }
        let target = "https://github.com/a/b/issues/1#review"
        let punctuated = "Review \(target)."
        let payload = Payload([Types.text: Data(punctuated.utf8), Types.html: Data("Review \(html(target)).".utf8)])
        XCTAssertNil(
            builder.build(try XCTUnwrap(Parser().parseText(punctuated)), source: payload),
            "A known anchor target must not silently gain punctuation")
    }
    @MainActor func testOptInStillRejectsSensitiveTypesAndChangesDuringReadingOrRestore() async throws {
        let board = NSPasteboard(name: .init("Pink.tests.\(UUID())"))
        defer { board.releaseGlobally() }
        let observed = ObservedBoard(board)
        let (_, original) = fixture()
        let monitor = ClipboardMonitor(
            board: observed, builder: NativeRepresentations(rewriteFormattedURLs: true), permission: HTMLPermission(),
            scheduler: HTMLScheduler(), parser: try Parser())
        monitor.enable()
        for marker in [
            "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "com.apple.is-remote-clipboard",
            "public.png", "org.chromium.web-custom-data",
        ] {
            var unsafe = original
            unsafe.values[marker] = Data()
            XCTAssertTrue(observed.native.write(unsafe))
            monitor.tick()
            XCTAssertEqual(observed.reads, 0)
            XCTAssertEqual(observed.writes, 0)
        }
        let external = Payload([Types.text: Data("new external text".utf8)])
        observed.afterRead = { _ = observed.native.write(external) }
        XCTAssertTrue(observed.native.write(original))
        monitor.tick()
        XCTAssertEqual(observed.writes, 0)
        XCTAssertEqual(observed.native.read(), external)
        observed.afterRead = nil
        XCTAssertTrue(observed.native.write(original))
        monitor.tick()
        XCTAssertTrue(monitor.canRestore)
        XCTAssertTrue(observed.native.write(external))
        monitor.restore()
        XCTAssertEqual(observed.native.read(), external)
        XCTAssertFalse(monitor.canRestore)
        monitor.pause()
    }
    @MainActor private func rtf(_ value: NSAttributedString) throws -> Data {
        try value.data(
            from: NSRange(location: 0, length: value.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }
    @MainActor private func readRTF(_ data: Data) throws -> NSAttributedString {
        try NSAttributedString(
            data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
    }
}
