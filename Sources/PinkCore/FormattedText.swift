import Foundation

public enum TextPart: Equatable, Sendable {
    case text(String)
    case reference(Reference)
}

/// A bounded source document and disjoint replacements. Never reserialize the source.
public struct FormattedText: Equatable, Sendable {
    public let original: String
    public let parts: [TextPart]
    public var displayText: String {
        parts.map {
            switch $0 {
            case .text(let text): text
            case .reference(let reference): reference.label
            }
        }.joined()
    }
    public var singleReference: Reference? {
        guard parts.count == 1, case .reference(let reference) = parts[0] else { return nil }
        return reference
    }
    public var html: String {
        if let reference = singleReference { return reference.html }
        let content = parts.map {
            switch $0 {
            case .text(let text): Reference.escape(text)
            case .reference(let reference): reference.html
            }
        }.joined()
        // Explicit breaks survive receivers which remove inline whitespace styles.
        let lines = content.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").replacingOccurrences(of: "\n", with: "<br>")
        return "<span style=\"white-space: pre-wrap\">\(lines)</span>"
    }
}

extension Parser {
    /// Recognize bare URL tokens in prose; the strict route parser remains the authority.
    public func parseText(_ input: String) -> FormattedText? {
        guard !input.isEmpty, input.utf8.count <= 8192,
            !input.unicodeScalars.contains(where: {
                (CharacterSet.controlCharacters.contains($0) && ![9, 10, 13].contains($0.value))
                    || (0x202A...0x202E).contains($0.value) || (0x2066...0x2069).contains($0.value)
                    || [0x200E, 0x200F, 0x061C].contains($0.value)
            })
        else { return nil }
        if let reference = parse(input) { return FormattedText(original: input, parts: [.reference(reference)]) }
        // Do not reinterpret HTML source or named Markdown links as bare prose URLs.
        guard input.range(of: "<[/!?A-Za-z][^>]*>", options: .regularExpression) == nil else { return nil }
        let expression = try! NSRegularExpression(
            pattern: #"(?<![A-Za-z0-9+.-])[A-Za-z][A-Za-z0-9+.-]*://[^\s<>"`“”‘’]+"#)
        var parts: [TextPart] = []
        var cursor = input.startIndex
        for match in expression.matches(in: input, range: NSRange(input.startIndex..., in: input)) {
            guard let range = Range(match.range, in: input) else { continue }
            if range.lowerBound != input.startIndex {
                let previous = input[input.index(before: range.lowerBound)]
                guard previous.isWhitespace || "([{<\"'“‘".contains(previous) else { continue }
            }
            let prefix = String(input[..<range.lowerBound])
            guard prefix.range(of: #"\]\(\s*<?$"#, options: .regularExpression) == nil else { continue }
            var candidate = String(input[range])
            // A closing prose delimiter ends the token even when followed by a
            // comma or period, which would otherwise be valid fragment bytes.
            var openings: [Character] = []
            for index in candidate.indices {
                let character = candidate[index]
                if "([{".contains(character) { openings.append(character) }
                if let opening = [")": "(", "]": "[", "}": "{"][String(character)] {
                    guard openings.last.map(String.init) == opening else {
                        candidate = String(candidate[..<index])
                        break
                    }
                    openings.removeLast()
                }
            }
            // Single quotes wrap prose too, but may also occur inside a URL query.
            if prefix.last == "'", let closing = candidate.lastIndex(of: "'"),
                candidate[candidate.index(after: closing)...].allSatisfy({ ".,;:!?".contains($0) })
            {
                candidate = String(candidate[..<closing])
            }
            var reference: Reference?
            // Bound punctuation work as well as input bytes; never repeatedly parse
            // thousands of trailing punctuation characters on the main actor.
            for _ in 0..<32 {
                guard !candidate.isEmpty else { break }
                if let parsed = parse(candidate) {
                    reference = parsed
                    break
                }
                // Only remove punctuation when the full candidate is not a valid URL.
                // A valid query/fragment ending in punctuation keeps those exact bytes.
                guard let last = candidate.last, ".,;:!?'".contains(last) else { break }
                candidate.removeLast()
            }
            guard let reference else { continue }
            let end = input.index(range.lowerBound, offsetBy: candidate.count)
            if cursor < range.lowerBound { parts.append(.text(String(input[cursor..<range.lowerBound]))) }
            parts.append(.reference(reference))
            cursor = end
        }
        guard !parts.isEmpty else { return nil }
        if cursor < input.endIndex { parts.append(.text(String(input[cursor...]))) }
        return FormattedText(original: input, parts: parts)
    }
}
