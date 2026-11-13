import AppKit
import RefPasteCore

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
    public func build(_ reference: Reference) -> Payload? {
        guard URL(string: reference.original) != nil else { return nil }
        let attributed = NSAttributedString(string: reference.label, attributes: [.link: reference.original])
        guard
            let rtf = try? attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        else { return nil }
        return Payload([
            Types.text: Data(reference.original.utf8), Types.url: Data(reference.original.utf8),
            Types.html: Data(reference.html.utf8), Types.rtf: rtf,
        ])
    }
    public func hasNamedLink(_ payload: Payload, original: String) -> Bool {
        // HTML import may load external resources. Never import untrusted HTML.
        // Conservatively skip existing HTML, including named hyperlinks.
        if payload.values[Types.html] != nil { return true }
        for (type, document) in [(Types.rtf, NSAttributedString.DocumentType.rtf)] {
            guard let data = payload.values[type] else { continue }
            guard
                let value = try? NSAttributedString(
                    data: data, options: [.documentType: document], documentAttributes: nil)
            else { return true }
            // Conservative: rich content must be exactly the original URL, even if it has no link attribute.
            if value.string != original { return true }
            var conflict = false
            value.enumerateAttribute(.link, in: NSRange(location: 0, length: value.length)) { link, _, _ in
                if let link, String(describing: link) != original { conflict = true }
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
