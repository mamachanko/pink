import Foundation

// Validation is shared by presets, custom rules and preview. Targets are never reserialized.
struct LinkURL: Sendable {
    let components: URLComponents
    let scheme: String
    let host: String
    let path: String
    let parts: [String]
    init?(_ input: String) {
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
        // Read the path from the original bytes: Foundation may double-encode existing
        // escapes when a URL also contains literal Unicode. Decode for matching only.
        let encodedPath = String(input[authority.endIndex...].prefix { !"?#".contains($0) })
        // Unreserved escapes, UTF-8 and encoded spaces in filenames are supported.
        // Encoded separators and reserved bytes cannot change route boundaries.
        let encodedBytes = Array(encodedPath.utf8)
        for i in encodedBytes.indices where encodedBytes[i] == 37 {
            let value = UInt8(String(bytes: encodedBytes[(i + 1)...(i + 2)], encoding: .utf8)!, radix: 16)!
            guard
                (48...57).contains(value) || (65...90).contains(value) || (97...122).contains(value)
                    || [32, 45, 46, 95, 126].contains(value) || value >= 128
            else { return nil }
        }
        guard let path = encodedPath.removingPercentEncoding, !path.contains("//") else { return nil }
        var parts = path.split(separator: "/", omittingEmptySubsequences: false).dropFirst().map(String.init)
        if parts.last == "" { parts.removeLast() }
        guard parts.allSatisfy(Self.segment) else { return nil }
        self.components = url
        self.scheme = scheme
        self.host = host
        self.parts = parts
        self.path = path
    }

    static func segment(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".."
            && value.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0) || CharacterSet.nonBaseCharacters.contains($0)
                    || " !$&'()*+,;=:@-._~".unicodeScalars.contains($0)
            }
    }
}
