import Foundation

#if canImport(FoundationXML)
    import FoundationXML
#endif

public struct SourceLink: Equatable, Sendable {
    public let range: NSRange
    public let target: String
}

/// A bounded fragment validator, not a browser/HTML importer. No resources are loaded.
public enum HTMLClipboard {
    public static func rawLinks(in data: Data, matching original: String) -> [SourceLink]? {
        guard data.count <= 65536, original.utf8.count <= 8192,
            let html = String(data: data, encoding: .utf8), let fragment = fragment(html)
        else { return nil }
        let reader = FragmentReader()
        let parser = XMLParser(data: Data(fragment.utf8))
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = reader
        guard parser.parse(), !reader.invalid else { return nil }
        let rich = MatchingText(reader.text)
        let plain = MatchingText(original)
        guard rich.units == plain.units else { return nil }
        var result: [SourceLink] = []
        for link in reader.links {
            guard let first = rich.starts.firstIndex(of: link.range.location),
                let last = rich.ends.lastIndex(of: NSMaxRange(link.range)), first <= last
            else { return nil }
            let range = NSRange(location: plain.starts[first], length: plain.ends[last] - plain.starts[first])
            guard (original as NSString).substring(with: range) == link.target else { return nil }
            result.append(SourceLink(range: range, target: link.target))
        }
        return result
    }

    fileprivate static let tags: Set<String> = [
        "html", "head", "body", "meta", "a", "span", "div", "p", "br", "b", "strong", "i", "em", "u", "s",
        "strike", "code", "pre", "blockquote", "ul", "ol", "li", "wbr",
    ]
    private static func fragment(_ input: String) -> String? {
        let input = input.hasPrefix("\u{FEFF}") ? String(input.dropFirst()) : input
        var output = "<pink-fragment>"
        var cursor = input.startIndex
        while cursor < input.endIndex {
            if input[cursor...].hasPrefix("<!--") {
                guard let end = input[cursor...].range(of: "-->") else { return nil }
                cursor = end.upperBound
                continue
            }
            if input[cursor] != "<" {
                let end = input[cursor...].firstIndex(of: "<") ?? input.endIndex
                output += input[cursor..<end]
                cursor = end
                continue
            }
            var end = input.index(after: cursor)
            var quote: Character?
            while end < input.endIndex {
                let character = input[end]
                if let current = quote {
                    if character == current { quote = nil }
                } else if character == "\"" || character == "'" {
                    quote = character
                } else if character == ">" {
                    break
                }
                end = input.index(after: end)
            }
            guard end < input.endIndex else { return nil }
            let token = String(input[input.index(after: cursor)..<end])
            cursor = input.index(after: end)
            if token.lowercased() == "!doctype html" { continue }
            guard !token.hasPrefix("!"), !token.hasPrefix("?") else { return nil }
            let closing = token.hasPrefix("/")
            let content = closing ? String(token.dropFirst()) : token
            let name = String(content.prefix { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
            guard !name.isEmpty, tags.contains(name.lowercased()) else { return nil }
            let attributes = String(content.dropFirst(name.count))
            guard attributes.isEmpty || attributes.first?.isWhitespace == true || attributes.first == "/" else {
                return nil
            }
            let normalized = name.lowercased()
            if ["br", "meta", "wbr"].contains(normalized) {
                guard !closing else { return nil }
                let tail = attributes.trimmingCharacters(in: .whitespacesAndNewlines)
                output += "<\(normalized)\(attributes)\(tail.hasSuffix("/") ? "" : "/")>"
            } else {
                output += "<\(closing ? "/" : "")\(normalized)\(attributes)>"
            }
        }
        // HTML's common named entities, expressed as XML numeric references.
        // Unknown entities, unquoted attributes and malformed markup fail closed.
        for (name, scalar) in [
            "nbsp": 160, "ndash": 8211, "mdash": 8212, "lsquo": 8216, "rsquo": 8217,
            "ldquo": 8220, "rdquo": 8221, "hellip": 8230, "bull": 8226, "copy": 169, "reg": 174,
        ] { output = output.replacingOccurrences(of: "&\(name);", with: "&#\(scalar);") }
        return output + "</pink-fragment>"
    }
}

/// Normalize HTML layout whitespace only for matching; source bytes are never changed.
private struct MatchingText {
    var units: [UInt16] = []
    var starts: [Int] = []
    var ends: [Int] = []
    init(_ text: String) {
        for (offset, unit) in text.utf16.enumerated() {
            let whitespace = UnicodeScalar(unit).map { CharacterSet.whitespacesAndNewlines.contains($0) } ?? false
            if whitespace {
                if units.isEmpty { continue }
                if units.last == 32 {
                    ends[ends.count - 1] = offset + 1
                    continue
                }
                units.append(32)
            } else {
                units.append(unit)
            }
            starts.append(offset)
            ends.append(offset + 1)
        }
        if units.last == 32 {
            units.removeLast()
            starts.removeLast()
            ends.removeLast()
        }
    }
}

private final class FragmentReader: NSObject, XMLParserDelegate {
    var text = ""
    var links: [SourceLink] = []
    var invalid = false
    private var depth = 0
    private var anchor: (offset: Int, target: String)?
    private let blocks: Set<String> = ["div", "p", "pre", "blockquote", "ul", "ol", "li"]
    private func reject(_ parser: XMLParser) {
        invalid = true
        parser.abortParsing()
    }
    private func boundary() { if !text.isEmpty, text.last != "\n" { text += "\n" } }
    func parser(
        _ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
        attributes attributesDict: [String: String]
    ) {
        depth += 1
        guard depth <= 64, depth == 1 ? name == "pink-fragment" : HTMLClipboard.tags.contains(name) else {
            reject(parser)
            return
        }
        var attributes: [String: String] = [:]
        for (key, value) in attributesDict {
            let key = key.lowercased()
            guard attributes[key] == nil, !key.hasPrefix("on"), !["src", "srcset", "background"].contains(key)
            else {
                reject(parser)
                return
            }
            attributes[key] = value
        }
        if name == "meta" {
            guard attributes.count == 1, ["utf-8", "utf8"].contains(attributes["charset"]?.lowercased() ?? "")
            else {
                reject(parser)
                return
            }
        }
        if blocks.contains(name) || name == "br" { boundary() }
        if name == "a" {
            guard anchor == nil, let target = attributes["href"], !target.isEmpty,
                let url = URLComponents(string: target), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                url.host?.isEmpty == false, url.user == nil, url.password == nil,
                !target.unicodeScalars.contains(where: {
                    CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0)
                })
            else {
                reject(parser)
                return
            }
            anchor = (text.utf16.count, target)
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
        if text.utf8.count > 32768 { reject(parser) }
    }
    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespace: String) {
        self.parser(parser, foundCharacters: whitespace)
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "a" {
            guard let anchor, links.count < 128 else {
                reject(parser)
                return
            }
            let range = NSRange(location: anchor.offset, length: text.utf16.count - anchor.offset)
            guard (text as NSString).substring(with: range) == anchor.target else {
                reject(parser)
                return
            }
            links.append(SourceLink(range: range, target: anchor.target))
            self.anchor = nil
        }
        if blocks.contains(name) { boundary() }
        depth -= 1
    }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? { nil }
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) { reject(parser) }
    func parser(_ parser: XMLParser, validationErrorOccurred validationError: any Error) { reject(parser) }
}
