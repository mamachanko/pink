import AppKit
import RefPasteCore
import XCTest

@testable import RefPastePlatform

final class ClipboardProofTests: XCTestCase {
    @MainActor func testOneItemRichAndPlainRoundTrip() async throws {
        let board = NSPasteboard(name: .init("RefPaste.tests.\(UUID())"))
        defer { board.releaseGlobally() }
        let reference = try XCTUnwrap(Parser().parse("https://github.com/Acme/Widget/pull/123?q=a&b=c#review"))
        let payload = try XCTUnwrap(NativeRepresentations().build(reference))
        let adapter = NativeBoard(board)
        XCTAssertTrue(adapter.write(payload))
        XCTAssertEqual(board.pasteboardItems?.count, 1)
        XCTAssertEqual(board.string(forType: .string), reference.original)
        XCTAssertEqual(board.string(forType: .html), reference.html)
        let rtf = try XCTUnwrap(board.data(forType: .rtf))
        let rich = try NSAttributedString(
            data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertEqual(rich.string, "Acme/Widget#123")
        XCTAssertEqual((rich.attribute(.link, at: 0, effectiveRange: nil) as? URL)?.absoluteString, reference.original)
    }
}

extension ClipboardProofTests {
    @MainActor func testNamedRichLinksAndHTMLAreSkipped() async throws {
        let original = "https://github.com/a/b/pull/1"
        let reference = try XCTUnwrap(Parser().parse(original))
        let builder = NativeRepresentations()
        XCTAssertTrue(builder.hasNamedLink(try XCTUnwrap(builder.build(reference)), original: original))
        XCTAssertTrue(
            builder.hasNamedLink(
                Payload([Types.html: Data("<img src='https://example.invalid'>".utf8)]), original: original))
        let plain = NSAttributedString(string: original, attributes: [.link: URL(string: original)!])
        let data = try plain.data(
            from: NSRange(location: 0, length: plain.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        XCTAssertFalse(builder.hasNamedLink(Payload([Types.rtf: data]), original: original))
    }
    @MainActor func testUnknownTypesCannotBeRead() async throws {
        let board = NSPasteboard(name: .init("RefPaste.tests.\(UUID())"))
        defer { board.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("https://github.com/a/b/pull/1", forType: .string)
        item.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        board.writeObjects([item])
        XCTAssertNil(NativeBoard(board).read())
    }
}

@MainActor private struct AllowedPermission: PermissionPort { var canRead: Bool { true } }
@MainActor private final class ManualScheduler: SchedulerPort {
    func start(_ tick: @escaping @MainActor () -> Void) {}
    func stop() {}
}
extension ClipboardProofTests {
    @MainActor func testNativeMonitorOwnershipAndRestoration() async throws {
        let board = NSPasteboard(name: .init("RefPaste.tests.\(UUID())"))
        defer { board.releaseGlobally() }
        let adapter = NativeBoard(board)
        let original = Payload([Types.text: Data("https://github.com/a/b/pull/1".utf8)])
        XCTAssertTrue(adapter.write(original))
        let monitor = ClipboardMonitor(
            board: adapter, builder: NativeRepresentations(), permission: AllowedPermission(),
            scheduler: ManualScheduler(), parser: try Parser())
        monitor.enable()
        XCTAssertEqual(board.pasteboardItems?.first?.types.count, 1)
        monitor.process()
        XCTAssertEqual(board.pasteboardItems?.count, 1)
        XCTAssertTrue(monitor.canRestore)
        XCTAssertNotNil(board.data(forType: .init(Types.own)))
        XCTAssertNotNil(board.data(forType: .init(Types.generated)))
        monitor.restore()
        XCTAssertEqual(adapter.read(), original)
        XCTAssertFalse(monitor.canRestore)
        monitor.pause()
    }
}
