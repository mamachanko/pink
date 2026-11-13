import AppKit
import PinkCore

@MainActor public final class NativeBoard: PasteboardPort {
    private let board: NSPasteboard
    public init(_ board: NSPasteboard) { self.board = board }
    public var changeCount: Int { board.changeCount }
    public var advertisedTypes: [[String]] { (board.pasteboardItems ?? []).map { $0.types.map(\.rawValue) } }
    public func read() -> Payload? {
        guard let items = board.pasteboardItems, items.count == 1,
            Set(items[0].types.map(\.rawValue)).isSubset(of: Types.allowed.union([Types.own, Types.generated]))
        else { return nil }
        var result: [String: Data] = [:]
        for type in items[0].types {
            guard let data = items[0].data(forType: type), data.count <= 65536 else { return nil }
            result[type.rawValue] = data
        }
        return Payload(result)
    }
    public func readMarker() -> Data? {
        guard let items = board.pasteboardItems, items.count == 1,
            items[0].types.contains(.init(Types.own)),
            let data = items[0].data(forType: .init(Types.own)), data.count <= 64
        else { return nil }
        return data
    }
    public func write(_ payload: Payload) -> Bool {
        let item = NSPasteboardItem()
        for (key, value) in payload.values {
            guard item.setData(value, forType: .init(key)) else { return false }
        }
        board.clearContents()
        return board.writeObjects([item])
    }
}
@MainActor public struct NativeRepresentations: RepresentationBuilder {
    public init() {}
    public func build(_ text: FormattedText, source: Payload = Payload([:])) -> Payload? {
        guard !hasNamedLink(source, original: text.original) else { return nil }
        let attributed: NSMutableAttributedString
        if let data = source.values[Types.rtf] {
            guard let value = readRTF(data), value.string == text.original else { return nil }
            attributed = NSMutableAttributedString(attributedString: value)
        } else {
            attributed = NSMutableAttributedString(string: text.original)
        }
        // Work backwards in UTF-16 coordinates: each earlier source range stays valid.
        var offset = 0
        var replacements: [(NSRange, Reference)] = []
        for part in text.parts {
            switch part {
            case .text(let value): offset += (value as NSString).length
            case .reference(let reference):
                let range = NSRange(location: offset, length: (reference.original as NSString).length)
                replacements.append((range, reference))
                offset += range.length
            }
        }
        guard offset == attributed.length else { return nil }
        var existingLinks: [(NSRange, String)] = []
        attributed.enumerateAttribute(.link, in: NSRange(location: 0, length: attributed.length)) { link, range, _ in
            if let link { existingLinks.append((range, String(describing: link))) }
        }
        for (range, reference) in replacements {
            for (existing, target) in existingLinks where NSIntersectionRange(range, existing).length > 0 {
                // An existing raw autolink can provide a narrower boundary than
                // prose tokenization. Never silently change that known target.
                guard range == existing, reference.original == target else { return nil }
            }
        }
        for (range, reference) in replacements.reversed() {
            var attributes = attributed.attributes(at: range.location, effectiveRange: nil)
            attributes[.link] = reference.original
            attributed.replaceCharacters(
                in: range, with: NSAttributedString(string: reference.label, attributes: attributes))
        }
        guard
            let rtf = try? attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        else { return nil }
        var values = [Types.text: Data(text.original.utf8), Types.html: Data(text.html.utf8), Types.rtf: rtf]
        // public.url must describe the whole item, never one link inside prose.
        if let reference = text.singleReference { values[Types.url] = Data(reference.original.utf8) }
        return Payload(values)
    }
    private func readRTF(_ data: Data) -> NSAttributedString? {
        try? NSAttributedString(
            data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
    }
    public func hasNamedLink(_ payload: Payload, original: String) -> Bool {
        // HTML import may load external resources. Never import untrusted HTML.
        // Conservatively skip existing HTML, including named hyperlinks.
        if payload.values[Types.html] != nil { return true }
        if let data = payload.values[Types.rtf] {
            guard let value = readRTF(data) else { return true }
            if value.string != original { return true }
            var conflict = false
            let entire = NSRange(location: 0, length: value.length)
            value.enumerateAttribute(.attachment, in: entire) { attachment, _, _ in
                if attachment != nil { conflict = true }
            }
            value.enumerateAttribute(.link, in: entire) { link, range, _ in
                if let link,
                    (value.string as NSString).substring(with: range) != String(describing: link)
                {
                    conflict = true
                }
            }
            if conflict { return true }
        }
        return false
    }
}
@MainActor public final class TimerScheduler: SchedulerPort {
    private var timer: Timer?
    public init() {}
    public func start(_ tick: @escaping @MainActor () -> Void) {
        stop()
        let timer = Timer(timeInterval: 0.2, repeats: true) { _ in
            MainActor.assumeIsolated { tick() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}
@MainActor public struct NativePermission: PermissionPort {
    public init() {}
    public var canRead: Bool {
        if #available(macOS 15.4, *) {
            switch NSPasteboard.general.accessBehavior {
            case .alwaysDeny, .ask: return false
            case .default, .alwaysAllow: return true
            @unknown default: return false
            }
        }
        return true
    }
}
