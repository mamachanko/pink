import AppKit
import PinkCore
import XCTest

@testable import PinkPlatform

final class ClipboardProofTests: XCTestCase {
    @MainActor func testDefaultIconsKeepUTF16LinkRangesTargetsAndRestoreAcrossPreferenceChanges() async throws {
        var settings = Settings()
        settings.linkRules = [LinkRule.templates[0]]
        let sha = "b4b5edb2fea0da48684c39f517902ca6851fe523"
        let fixtures = [
            ("https://github.com/mamachanko/pink/pull/34", "🔀 mamachanko/pink#34", "mamachanko/pink#34"),
            (
                "https://github.com/mamachanko/pink/blob/\(sha)/App.swift#L2-L4",
                "📄 mamachanko/pink · b4b5edb2/App.swift:2–4", "mamachanko/pink · b4b5edb2/App.swift:2–4"
            ),
            (
                "https://github.com/mamachanko/pink/actions/workflows/ci.yml?query=branch%3Amain",
                "⚙️ mamachanko/pink · ci.yml", "mamachanko/pink · ci.yml"
            ),
            (
                "https://github.com/mamachanko/pink/actions/runs/44518099853/job/135539289334#step:2:1",
                "🛠️ mamachanko/pink · job 135539289334", "mamachanko/pink · job 135539289334"
            ),
            (
                "https://github.com/mamachanko/pink/commit/\(sha)?diff=split", "🔖 mamachanko/pink@b4b5edb2",
                "mamachanko/pink@b4b5edb2"
            ),
            ("https://github.com/acme/widget/releases/tag/v1.0", "🏷️ acme/widget@v1.0", "acme/widget@v1.0"),
            ("https://jira.example/browse/ACME-1", "🎫 ACME-1", "ACME-1"),
        ]
        let original = "👩🏽 Review\n" + fixtures.map { $0.0 }.joined(separator: "\n")
        XCTAssertNotNil(try Parser(settings: settings).parseText(original))
        let source = Payload([Types.text: Data(original.utf8)])
        let board = NSPasteboard(name: .init("Pink.tests.\(UUID())"))
        defer { board.releaseGlobally() }
        let adapter = NativeBoard(board)
        let monitor = ClipboardMonitor(
            board: adapter, builder: NativeRepresentations(), permission: AllowedPermission(),
            scheduler: ManualScheduler(), parser: try Parser(settings: settings))
        monitor.enable()
        XCTAssertTrue(adapter.write(source))
        monitor.tick()
        XCTAssertEqual(board.string(forType: .string), original)
        XCTAssertEqual(board.pasteboardItems?.count, 1)
        let rich = try NSAttributedString(
            data: XCTUnwrap(board.data(forType: .rtf)),
            options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertEqual(rich.string, "👩🏽 Review\n" + fixtures.map { $0.1 }.joined(separator: "\n"))
        var targets: [String] = []
        var labels: [String] = []
        rich.enumerateAttribute(.link, in: NSRange(location: 0, length: rich.length)) { value, range, _ in
            guard let value else { return }
            targets.append(String(describing: value))
            labels.append((rich.string as NSString).substring(with: range))
        }
        XCTAssertEqual(targets, fixtures.map { $0.0 })
        XCTAssertEqual(labels, fixtures.map { $0.1 })
        let generation = board.changeCount
        settings.showLinkIcons = false
        monitor.parser = try Parser(settings: settings)
        XCTAssertEqual(board.changeCount, generation)
        XCTAssertTrue(monitor.canRestore)
        monitor.restore()
        XCTAssertEqual(adapter.read(), source)
        XCTAssertTrue(adapter.write(source))
        monitor.tick()
        let plainLabels = try NSAttributedString(
            data: XCTUnwrap(board.data(forType: .rtf)),
            options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertEqual(plainLabels.string, "👩🏽 Review\n" + fixtures.map { $0.2 }.joined(separator: "\n"))
        XCTAssertEqual(board.string(forType: .string), original)
        monitor.restore()
        XCTAssertEqual(adapter.read(), source)
        monitor.pause()
    }

    @MainActor func testFilePermalinksAndLinesHaveExactNativeTargetsAndRestore() async throws {
        let sha = "0123456789abcdef0123456789abcdef01234567"
        var settings = Settings()
        settings.rules.append(.init(service: .github, host: "github.example", port: 8443, basePath: "/code"))
        let parser = try Parser(rules: settings.rules, linkRules: settings.linkRules)
        for (url, label) in [
            (
                "https://github.com/acme/widget/blob/\(sha)/App.swift?plain=1#L2-L4",
                "acme/widget · 01234567/App.swift:2–4"
            ),
            (
                "https://github.example:8443/code/acme/widget/blob/\(sha)/App.swift?x=%2F#L2-L4",
                "acme/widget · 01234567/App.swift:2–4"
            ),
            (
                "https://gitlab.com/team/sub/widget/-/blob/\(sha)/App.swift?ref_type=heads#L2-4",
                "team/sub/widget · 01234567/App.swift:2–4"
            ),
        ] {
            let board = NSPasteboard(name: .init("Pink.tests.\(UUID())"))
            defer { board.releaseGlobally() }
            let adapter = NativeBoard(board)
            let monitor = ClipboardMonitor(
                board: adapter, builder: NativeRepresentations(), permission: AllowedPermission(),
                scheduler: ManualScheduler(), parser: parser)
            monitor.enable()
            let text = "Review \(url) please"
            let source = Payload([Types.text: Data(text.utf8)])
            XCTAssertTrue(adapter.write(source))
            monitor.tick()
            XCTAssertEqual(board.pasteboardItems?.count, 1)
            XCTAssertEqual(board.string(forType: .string), text)
            let rich = try NSAttributedString(
                data: XCTUnwrap(board.data(forType: .rtf)),
                options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            XCTAssertEqual(rich.string, "Review \(label) please")
            let range = (rich.string as NSString).range(of: label)
            let location = try XCTUnwrap(range.location == NSNotFound ? nil : range.location)
            let target = try XCTUnwrap(rich.attribute(.link, at: location, effectiveRange: nil))
            XCTAssertEqual(String(describing: target), url)
            monitor.restore()
            XCTAssertEqual(adapter.read(), source)
            monitor.pause()
        }
    }

    @MainActor func testSuggestedJiraFormatSavesOnceAndFormatsANewTicketNatively() async throws {
        let domain = "Pink.tests.builder.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = SettingsStore(defaults: defaults, legacyDomain: nil)
        var enabled = try store.load()
        enabled.consent = true
        enabled.automatic = true
        let session = try SettingsSession(initial: enabled, persist: store.save)
        let draft = LinkBuilderDraft(example: "https://jira.example/browse/ACME-184273", settings: enabled)
        XCTAssertTrue(draft.canFinish(in: enabled))
        let rule = try XCTUnwrap(draft.candidate)
        try session.edit { $0.linkRules.insert(rule, at: 0) }

        let saved = try store.load()
        let board = NSPasteboard(name: .init("Pink.tests.\(UUID())"))
        defer { board.releaseGlobally() }
        let adapter = NativeBoard(board)
        let monitor = ClipboardMonitor(
            board: adapter, builder: NativeRepresentations(), permission: AllowedPermission(),
            scheduler: ManualScheduler(), parser: try Parser(rules: saved.rules, linkRules: saved.linkRules))
        monitor.enable()
        let url = "https://jira.example/browse/OTHER-52?x=a&b=%2F#comment-9"
        let source = Payload([Types.text: Data(url.utf8), Types.url: Data(url.utf8)])
        XCTAssertTrue(adapter.write(source))
        monitor.tick()
        XCTAssertEqual(board.pasteboardItems?.count, 1)
        XCTAssertEqual(board.string(forType: .string), url)
        XCTAssertEqual(board.string(forType: .URL), url)
        let rich = try NSAttributedString(
            data: XCTUnwrap(board.data(forType: .rtf)),
            options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertEqual(rich.string, "OTHER-52")
        XCTAssertEqual(String(describing: rich.attribute(.link, at: 0, effectiveRange: nil)!), url)
        XCTAssertTrue(monitor.canRestore)
        monitor.restore()
        XCTAssertEqual(adapter.read(), source)
        monitor.pause()
    }

    @MainActor func testCopiedHTMLAutolinkCanBeShortened() async throws {
        let url = "https://github.com/acme/widget/pull/123"
        let original = "Review \(url) please"
        let source = Payload([
            Types.text: Data(original.utf8),
            Types.html: Data("<meta charset='utf-8'><span>Review <a href='\(url)'>\(url)</a> please</span>".utf8),
        ])
        let text = try XCTUnwrap(Parser().parseText(original))
        XCTAssertNil(NativeRepresentations().build(text, source: source))
        let output = try XCTUnwrap(NativeRepresentations(rewriteFormattedURLs: true).build(text, source: source))
        XCTAssertEqual(output.string(Types.text), original)
        let rich = try NSAttributedString(
            data: XCTUnwrap(output.values[Types.rtf]),
            options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertEqual(rich.string, "Review acme/widget#123 please")
    }
    @MainActor func testCustomAndExpandedGitHubLinksUseNativeRepresentations() async throws {
        let board = NSPasteboard(name: .init("Pink.tests.\(UUID())"))
        defer { board.releaseGlobally() }
        let parser = try Parser(linkRules: [
            LinkRule(name: "Jira", urlPattern: "https://jira.example/browse/{issue}", labelTemplate: "{issue}")
        ])
        let urls = [
            "https://jira.example/browse/ACME-184273?x=a&b=%2F#comment-2",
            "https://github.com/acme/widget",
            "https://github.com/acme/widget/blob/main/Sources/App.swift#L10-L20",
            "https://github.com/acme/widget/releases/tag/v1.2.3",
        ]
        let labels = ["ACME-184273", "acme/widget", "acme/widget · main/Sources/App.swift:10–20", "acme/widget@v1.2.3"]
        for (url, label) in zip(urls, labels) {
            let formatted = try XCTUnwrap(parser.parseText(url))
            let payload = try XCTUnwrap(NativeRepresentations().build(formatted))
            XCTAssertTrue(NativeBoard(board).write(payload))
            XCTAssertEqual(board.pasteboardItems?.count, 1)
            XCTAssertEqual(board.string(forType: .string), url)
            XCTAssertEqual(board.string(forType: .URL), url)
            let rich = try NSAttributedString(
                data: XCTUnwrap(board.data(forType: .rtf)),
                options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            XCTAssertEqual(rich.string, label)
            XCTAssertEqual(String(describing: rich.attribute(.link, at: 0, effectiveRange: nil)!), url)
        }
    }

    @MainActor func testOneItemRichAndPlainRoundTrip() async throws {
        let board = NSPasteboard(name: .init("Pink.tests.\(UUID())"))
        defer { board.releaseGlobally() }
        let reference = try XCTUnwrap(Parser().parseText("https://github.com/Acme/Widget/pull/123?q=a&b=c#review"))
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
        let reference = try XCTUnwrap(Parser().parseText(original))
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
        let board = NSPasteboard(name: .init("Pink.tests.\(UUID())"))
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
        let board = NSPasteboard(name: .init("Pink.tests.\(UUID())"))
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

extension ClipboardProofTests {
    @MainActor func testProseMultipleLinksMonitorRoundTripAndRestore() async throws {
        let board = NSPasteboard(name: .init("Pink.tests.\(UUID())"))
        defer { board.releaseGlobally() }
        let adapter = NativeBoard(board)
        let first = "https://github.com/Acme/Widget/pull/123?q=a&b=c#review"
        let second = "https://gitlab.com/Group/Sub/Repo/-/merge_requests/45/diffs"
        let input = "💕 Équipe e\u{301}: ((\(first))),\nthen \(second) and \(first) again. Done."
        let expected =
            "💕 Équipe e\u{301}: ((Acme/Widget#123)),\nthen Group/Sub/Repo!45 and Acme/Widget#123 again. Done."
        let original = Payload([Types.text: Data(input.utf8)])
        let monitor = ClipboardMonitor(
            board: adapter, builder: NativeRepresentations(), permission: AllowedPermission(),
            scheduler: ManualScheduler(), parser: try Parser())
        monitor.enable()
        XCTAssertTrue(adapter.write(original))
        monitor.tick()
        XCTAssertEqual(board.pasteboardItems?.count, 1)
        XCTAssertEqual(board.string(forType: .string), input)
        XCTAssertNil(board.data(forType: .URL))
        XCTAssertEqual(board.string(forType: .html), try Parser().parseText(input)?.html)
        let rich = try NSAttributedString(
            data: XCTUnwrap(board.data(forType: .rtf)),
            options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertEqual(rich.string, expected)
        var labels: [String] = []
        var targets: [String] = []
        rich.enumerateAttribute(.link, in: NSRange(location: 0, length: rich.length)) { link, range, _ in
            guard let link else { return }
            labels.append((rich.string as NSString).substring(with: range))
            targets.append(String(describing: link))
        }
        XCTAssertEqual(labels, ["Acme/Widget#123", "Group/Sub/Repo!45", "Acme/Widget#123"])
        XCTAssertEqual(targets, [first, second, first])
        XCTAssertNil(rich.attribute(.link, at: 0, effectiveRange: nil))
        XCTAssertTrue(monitor.canRestore)
        let count = board.changeCount
        monitor.tick()
        XCTAssertEqual(board.changeCount, count)
        monitor.restore()
        XCTAssertEqual(adapter.read(), original)
        // A repeated identical copy is a new generation, not a self-write.
        XCTAssertTrue(adapter.write(original))
        monitor.tick()
        XCTAssertTrue(monitor.canRestore)
        let external = Payload([Types.text: Data("new external text".utf8)])
        XCTAssertTrue(adapter.write(external))
        monitor.restore()
        XCTAssertEqual(adapter.read(), external)
        XCTAssertFalse(monitor.canRestore)
        monitor.pause()
    }

    @MainActor func testRichProseStylesAndRawAutolinksArePreserved() async throws {
        let url = "https://github.com/Acme/Widget/issues/2"
        let input = "Review \(url) please"
        let source = NSMutableAttributedString(string: input, attributes: [.font: NSFont.boldSystemFont(ofSize: 14)])
        source.addAttribute(.link, value: url, range: (input as NSString).range(of: url))
        let rtf = try source.data(
            from: NSRange(location: 0, length: source.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let builder = NativeRepresentations()
        let payload = Payload([Types.text: Data(input.utf8), Types.rtf: rtf])
        XCTAssertFalse(builder.hasNamedLink(payload, original: input))
        let formatted = try XCTUnwrap(Parser().parseText(input))
        let output = try XCTUnwrap(builder.build(formatted, source: payload))
        let rich = try NSAttributedString(
            data: XCTUnwrap(output.values[Types.rtf]),
            options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertEqual(rich.string, "Review Acme/Widget#2 please")
        let label = (rich.string as NSString).range(of: "Acme/Widget#2")
        XCTAssertEqual(String(describing: rich.attribute(.link, at: label.location, effectiveRange: nil)!), url)
        for index in [0, label.location, rich.length - 1] {
            let font = try XCTUnwrap(rich.attribute(.font, at: index, effectiveRange: nil) as? NSFont)
            XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        }
    }

    @MainActor func testProseNamedLinksConflictingRTFAndHTMLAreSkipped() async throws {
        let url = "https://github.com/a/b/pull/1"
        let input = "Review \(url) then named"
        let named = NSMutableAttributedString(string: input)
        named.addAttribute(.link, value: "https://example.invalid", range: (input as NSString).range(of: "named"))
        let data = try named.data(
            from: NSRange(location: 0, length: named.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let builder = NativeRepresentations()
        let parsed = try XCTUnwrap(Parser().parseText(input))
        for source in [
            Payload([Types.text: Data(input.utf8), Types.rtf: data]),
            Payload([Types.text: Data(input.utf8), Types.rtf: Data("invalid RTF".utf8)]),
            Payload([
                Types.text: Data(input.utf8), Types.html: Data("<a href='https://example.invalid'>named</a>".utf8),
            ]),
        ] {
            XCTAssertTrue(builder.hasNamedLink(source, original: input))
            XCTAssertNil(builder.build(parsed, source: source))
        }
        XCTAssertTrue(builder.hasNamedLink(Payload([Types.rtf: data]), original: input + " different"))
        let target = url + "#review"
        let punctuated = "Review \(target)."
        let autolink = NSMutableAttributedString(string: punctuated)
        autolink.addAttribute(.link, value: target, range: (punctuated as NSString).range(of: target))
        let autolinkRTF = try autolink.data(
            from: NSRange(location: 0, length: autolink.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let raw = Payload([Types.text: Data(punctuated.utf8), Types.rtf: autolinkRTF])
        XCTAssertFalse(builder.hasNamedLink(raw, original: punctuated))
        // The full token's fragment includes '.', unlike the existing hyperlink.
        // Skip rather than silently replace an already-known target.
        XCTAssertNil(builder.build(try XCTUnwrap(Parser().parseText(punctuated)), source: raw))
    }

    @MainActor func testUnicodeRTFRoundTrip() async throws {
        let original = "https://gitlab.com/%C3%89quipe/Sous/Projet/-/merge_requests/1?x=a&b=c#note"
        let reference = try XCTUnwrap(Parser().parseText(original))
        let payload = try XCTUnwrap(NativeRepresentations().build(reference))
        let rtf = try XCTUnwrap(payload.values[Types.rtf])
        let rich = try NSAttributedString(
            data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertEqual(rich.string, "Équipe/Sous/Projet!1")
        XCTAssertEqual((rich.attribute(.link, at: 0, effectiveRange: nil) as? URL)?.absoluteString, original)
    }
}
