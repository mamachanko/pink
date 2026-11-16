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
    public let linkRules: [LinkRule]
    private let compiledRules: [CompiledLinkRule]

    public init(rules: [HostRule] = HostRule.defaults, linkRules: [LinkRule] = []) throws {
        guard linkRules.count <= 64, Set(linkRules.map(\.id)).count == linkRules.count else {
            throw LinkRuleError.tooManyRules
        }
        self.linkRules = linkRules
        self.compiledRules = try linkRules.map(CompiledLinkRule.init)
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
    static func segment(_ s: String) -> Bool {
        !s.isEmpty && s != "." && s != ".."
            && s.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0) || CharacterSet.nonBaseCharacters.contains($0)
                    || [45, 46, 95, 126].contains($0.value)
            }
    }
    public func parse(_ input: String) -> Reference? { matches(input).first?.reference }

    /// Ordered candidates: explicit overrides, the service preset, then remaining custom rules.
    public func matches(_ input: String) -> [LinkMatch] {
        guard let url = LinkURL(input) else { return [] }
        let custom = compiledRules.compactMap { $0.match(url, original: input) }
        var matches = custom.filter { $0.overridesBuiltIns }.map(\.match)
        if let reference = preset(url, original: input) {
            matches.append(LinkMatch(ruleName: "\(url.host) preset", reference: reference, captures: [:]))
        }
        matches += custom.filter { !$0.overridesBuiltIns }.map(\.match)
        return matches
    }

    private func preset(_ url: LinkURL, original: String) -> Reference? {
        let path = url.path
        guard
            let rule = rules.first(where: {
                $0.enabled && $0.host.lowercased() == url.host.lowercased() && $0.port == url.components.port
                    && (url.scheme == "https" || $0.allowHTTP) && path.hasPrefix($0.basePath + "/")
            })
        else { return nil }
        let parts = Array(url.parts.dropFirst(rule.basePath.split(separator: "/").count))
        switch rule.service {
        case .github:
            guard parts.count >= 2, parts.prefix(2).allSatisfy(Self.segment),
                !parts[1].hasSuffix("."), !Self.githubReservedOwners.contains(parts[0].lowercased())
            else { return nil }
            let repository = parts.prefix(2).joined(separator: "/")
            if parts.count == 2 { return Reference(original: original, label: repository) }
            if (4...5).contains(parts.count), ["pull", "issues"].contains(parts[2]),
                parts.count == 4 || ["files", "commits", "checks"].contains(parts[4]), Self.number(parts[3])
            {
                return Reference(original: original, label: repository + "#" + parts[3])
            }
            if parts.count >= 5, parts[2] == "blob" {
                // Keep revision/path together: slash-containing refs cannot be resolved offline.
                var label = repository + " · " + parts.dropFirst(3).joined(separator: "/")
                if let fragment = url.components.fragment,
                    fragment.range(of: #"^L[0-9]+(?:-L[0-9]+)?$"#, options: .regularExpression) != nil
                {
                    label += ":" + fragment.replacingOccurrences(of: "-L", with: "–").dropFirst()
                }
                return Reference(original: original, label: label)
            }
            if parts.count >= 5, parts[2] == "releases", parts[3] == "tag" {
                return Reference(
                    original: original, label: repository + "@" + parts.dropFirst(4).joined(separator: "/"))
            }
            return nil
        case .gitlab:
            guard let dash = parts.firstIndex(of: "-"), dash >= 2, (dash + 3...dash + 4).contains(parts.count),
                ["merge_requests", "issues"].contains(parts[dash + 1]),
                parts.count == dash + 3
                    || (parts[dash + 1] == "merge_requests"
                        && ["diffs", "commits", "pipelines"].contains(parts[dash + 3])),
                parts.prefix(dash).allSatisfy(Self.segment), Self.number(parts[dash + 2])
            else { return nil }
            let symbol = parts[dash + 1] == "issues" ? "#" : "!"
            return Reference(
                original: original, label: parts.prefix(dash).joined(separator: "/") + symbol + parts[dash + 2])
        }
    }

    private static func number(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (48...57).contains($0) } && value.contains { $0 != "0" }
    }

    // These are site routes, not repository owners. Favor leaving uncertain URLs untouched.
    private static let githubReservedOwners: Set<String> = [
        "about", "account", "apps", "collections", "contact", "customer-stories", "enterprise", "events", "explore",
        "features", "issues", "login", "logout", "marketplace", "new", "notifications", "organizations", "orgs",
        "pricing", "pulls", "search", "security", "sessions", "settings", "signup", "site", "sponsors", "topics",
        "trending",
        "users",
    ]
}
