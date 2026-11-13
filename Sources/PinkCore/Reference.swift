import Foundation

public enum Service: String, Codable, CaseIterable, Sendable { case github, gitlab }

public struct HostRule: Codable, Equatable, Sendable {
    public var service: Service
    public var host: String
    public var port: Int?
    public var basePath: String
    public var enabled: Bool
    public var allowHTTP: Bool

    public init(
        service: Service, host: String, port: Int? = nil, basePath: String = "", enabled: Bool = true,
        allowHTTP: Bool = false
    ) {
        self.service = service
        self.host = host
        self.port = port
        self.basePath = basePath
        self.enabled = enabled
        self.allowHTTP = allowHTTP
    }
    public static let defaults = [
        HostRule(service: .github, host: "github.com"), HostRule(service: .gitlab, host: "gitlab.com"),
    ]
}

public enum ValidationError: Error { case invalidRules }

public struct Reference: Equatable, Sendable {
    public let original: String
    public let label: String
    public var html: String { "<a href=\"\(Self.escape(original))\">\(Self.escape(label))</a>" }
    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

public struct Parser: Sendable {
    public let rules: [HostRule]
    public init(rules: [HostRule] = HostRule.defaults) throws {
        for (i, r) in rules.enumerated() {
            let labels = r.host.split(separator: ".", omittingEmptySubsequences: false)
            guard r.host.utf8.count <= 253, !labels.isEmpty,
                labels.allSatisfy({ label in
                    !label.isEmpty && label.count <= 63 && label.first != "-" && label.last != "-"
                        && label.utf8.allSatisfy {
                            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45
                        }
                }), r.port == nil || (1...65535).contains(r.port!),
                r.basePath.isEmpty
                    || (r.basePath.hasPrefix("/") && !r.basePath.hasSuffix("/")
                        && r.basePath.split(separator: "/", omittingEmptySubsequences: false).dropFirst().allSatisfy({
                            Self.segment(String($0))
                        })),
                !(r.allowHTTP && ["github.com", "gitlab.com"].contains(r.host.lowercased()))
            else { throw ValidationError.invalidRules }
            for other in rules.prefix(i)
            where r.enabled && other.enabled && r.host.lowercased() == other.host.lowercased() && r.port == other.port {
                if r.basePath == other.basePath || r.basePath.hasPrefix(other.basePath + "/")
                    || other.basePath.hasPrefix(r.basePath + "/")
                {
                    throw ValidationError.invalidRules
                }
            }
        }
        self.rules = rules
    }
    private static func segment(_ s: String) -> Bool {
        !s.isEmpty && s != "." && s != ".."
            && s.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0) || CharacterSet.nonBaseCharacters.contains($0)
                    || [45, 46, 95, 126].contains($0.value)
            }
    }
    public func parse(_ input: String) -> Reference? {
        guard input.utf8.count <= 8192, !input.isEmpty,
            !input.unicodeScalars.contains(where: {
                CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0)
                    || (0x202A...0x202E).contains($0.value) || (0x2066...0x2069).contains($0.value)
                    || [0x200E, 0x200F, 0x061C].contains($0.value)
            }),
            !input.contains("\\"), !input.contains("<"), !input.contains(">"),
            let url = URLComponents(string: input), let scheme = url.scheme?.lowercased(),
            ["https", "http"].contains(scheme), url.user == nil, url.password == nil,
            let host = url.host, let authorityStart = input.range(of: "://")
        else { return nil }
        // Validate escapes ourselves: Foundation may repair malformed percent sequences.
        let bytes = Array(input.utf8)
        for i in bytes.indices where bytes[i] == 37 {
            guard i + 2 < bytes.count,
                bytes[(i + 1)...(i + 2)].allSatisfy({
                    (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
                })
            else { return nil }
            let hex = String(bytes: bytes[(i + 1)...(i + 2)], encoding: .utf8)!
            let value = UInt8(hex, radix: 16)!
            if value < 32 || value == 127 { return nil }
        }
        let authority = input[authorityStart.upperBound...].prefix { !"/?#".contains($0) }
        if authority.contains(":") {
            guard let p = authority.split(separator: ":", omittingEmptySubsequences: false).last,
                !p.isEmpty, p.utf8.allSatisfy({ (48...57).contains($0) }), let n = Int(p), (1...65535).contains(n)
            else { return nil }
        }
        guard let decoded = input.removingPercentEncoding,
            !decoded.unicodeScalars.contains(where: {
                CharacterSet.controlCharacters.contains($0) || (0x202A...0x202E).contains($0.value)
                    || (0x2066...0x2069).contains($0.value) || [0x200E, 0x200F, 0x061C].contains($0.value)
            })
        else { return nil }
        let encodedPath = url.percentEncodedPath
        // Decode only RFC 3986 unreserved escapes. Separators and reserved bytes
        // remain rejected rather than changing route boundaries.
        let encodedBytes = Array(encodedPath.utf8)
        for i in encodedBytes.indices where encodedBytes[i] == 37 {
            let value = UInt8(String(bytes: encodedBytes[(i + 1)...(i + 2)], encoding: .utf8)!, radix: 16)!
            guard
                (48...57).contains(value) || (65...90).contains(value) || (97...122).contains(value)
                    || [45, 46, 95, 126].contains(value) || value >= 128
            else { return nil }
        }
        guard let path = encodedPath.removingPercentEncoding, !path.contains("//"),
            let r = rules.first(where: {
                $0.enabled && $0.host.lowercased() == host.lowercased() && $0.port == url.port
                    && (scheme == "https" || $0.allowHTTP) && (path.hasPrefix($0.basePath + "/"))
            })
        else { return nil }
        var parts = String(path.dropFirst(r.basePath.count + 1)).split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        if parts.last == "" { parts.removeLast() }
        let namespace: [String]
        let number: String
        let symbol: String
        switch r.service {
        case .github:
            guard (4...5).contains(parts.count), ["pull", "issues"].contains(parts[2]),
                parts.count == 4 || ["files", "commits", "checks"].contains(parts[4])
            else { return nil }
            namespace = Array(parts.prefix(2))
            number = parts[3]
            symbol = "#"
        case .gitlab:
            guard let dash = parts.firstIndex(of: "-"), dash >= 2, (dash + 3...dash + 4).contains(parts.count),
                ["merge_requests", "issues"].contains(parts[dash + 1]),
                parts.count == dash + 3
                    || (parts[dash + 1] == "merge_requests"
                        && ["diffs", "commits", "pipelines"].contains(parts[dash + 3]))
            else { return nil }
            namespace = Array(parts.prefix(dash))
            number = parts[dash + 2]
            symbol = parts[dash + 1] == "issues" ? "#" : "!"
        }
        guard namespace.allSatisfy(Self.segment), !number.isEmpty,
            number.utf8.allSatisfy({ (48...57).contains($0) }), number.contains(where: { $0 != "0" })
        else { return nil }
        return Reference(original: input, label: namespace.joined(separator: "/") + symbol + number)
    }
}
