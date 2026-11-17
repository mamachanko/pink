import Foundation

public struct LinkRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var urlPattern: String
    public var labelTemplate: String
    public var enabled: Bool
    public var overridesBuiltIns: Bool

    public init(
        id: UUID = UUID(), name: String, urlPattern: String, labelTemplate: String,
        enabled: Bool = true, overridesBuiltIns: Bool = false
    ) {
        self.id = id
        self.name = name
        self.urlPattern = urlPattern
        self.labelTemplate = labelTemplate
        self.enabled = enabled
        self.overridesBuiltIns = overridesBuiltIns
    }

    /// Copies for the builder, not enabled global rules. Examples use public or reserved hosts.
    public static var templates: [LinkRule] {
        [
            LinkRule(name: "Jira issue", urlPattern: "https://jira.example/browse/{issue}", labelTemplate: "{issue}"),
            LinkRule(
                name: "GitHub pull request", urlPattern: "https://github.com/{owner}/{repo}/pull/{number}",
                labelTemplate: "{owner}/{repo}#{number}", overridesBuiltIns: true),
            LinkRule(
                name: "GitHub issue", urlPattern: "https://github.com/{owner}/{repo}/issues/{number}",
                labelTemplate: "{owner}/{repo}#{number}", overridesBuiltIns: true),
            LinkRule(
                name: "GitHub repository", urlPattern: "https://github.com/{owner}/{repo}",
                labelTemplate: "{owner}/{repo}", overridesBuiltIns: true),
            LinkRule(
                name: "GitHub file", urlPattern: "https://github.com/{owner}/{repo}/blob/{path...}",
                labelTemplate: "{owner}/{repo} · {path}", overridesBuiltIns: true),
            LinkRule(
                name: "GitHub release", urlPattern: "https://github.com/{owner}/{repo}/releases/tag/{tag...}",
                labelTemplate: "{owner}/{repo}@{tag}", overridesBuiltIns: true),
            LinkRule(
                name: "GitLab issue", urlPattern: "https://gitlab.com/{group}/{repo}/-/issues/{number}",
                labelTemplate: "{group}/{repo}#{number}", overridesBuiltIns: true),
            LinkRule(
                name: "GitLab merge request", urlPattern: "https://gitlab.com/{group}/{repo}/-/merge_requests/{number}",
                labelTemplate: "{group}/{repo}!{number}", overridesBuiltIns: true),
        ]
    }
}

public struct LinkMatch: Equatable, Sendable {
    public let ruleName: String
    public let reference: Reference
    public let captures: [String: String]
}

public enum LinkRuleError: String, Error, LocalizedError {
    case tooManyRules = "Use at most 64 rules with unique identifiers."
    case invalidName = "Give the rule a name of 1–80 characters."
    case invalidPattern =
        "Use an exact HTTP(S) host and path. Patterns cannot contain queries, fragments or credentials."
    case invalidCapture = "Use unique {names} for path segments, or {path...} at the end. Names start with a letter."
    case invalidLabel = "Use a label of 1–512 characters containing text and known {names}."

    public var errorDescription: String? { rawValue }
}

struct CompiledLinkRule: Sendable {
    enum Segment: Sendable {
        case literal(String)
        case capture(String)
        case remainder(String)
    }
    enum LabelPart: Sendable {
        case literal(String)
        case capture(String)
    }

    let rule: LinkRule
    let scheme: String
    let host: String
    let port: Int?
    let segments: [Segment]
    let label: [LabelPart]

    init(_ rule: LinkRule) throws {
        guard !rule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            rule.name.count <= 80, Self.safeText(rule.name)
        else { throw LinkRuleError.invalidName }
        guard rule.urlPattern.utf8.count <= 2048, let url = URLComponents(string: rule.urlPattern),
            let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme), let host = url.host,
            url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
            rule.urlPattern.contains("://"), !rule.urlPattern.contains("\\"),
            Self.safeText(rule.urlPattern), !rule.urlPattern.contains(where: { $0.isWhitespace }),
            !host.contains("{"), !host.contains("}")
        else { throw LinkRuleError.invalidPattern }
        do {
            _ = try Parser(rules: [.init(service: .github, host: host, port: url.port, allowHTTP: scheme == "http")])
        } catch { throw LinkRuleError.invalidPattern }
        // URLComponents may repair invalid authorities; validate the literal endpoint independently.
        let authority = rule.urlPattern[rule.urlPattern.range(of: "://")!.upperBound...].prefix { $0 != "/" }
        guard LinkURL("\(scheme)://\(authority)/") != nil else { throw LinkRuleError.invalidPattern }
        let rawPath = rule.urlPattern[authority.endIndex...]
        var path = rawPath.split(separator: "/", omittingEmptySubsequences: false).dropFirst().map(String.init)
        if path.last == "" { path.removeLast() }
        guard path.count <= 64 else { throw LinkRuleError.invalidPattern }
        var names: Set<String> = []
        var segments: [Segment] = []
        var validationPath: [String] = []
        for (index, component) in path.enumerated() {
            if component.hasPrefix("{"), component.hasSuffix("}") {
                var name = String(component.dropFirst().dropLast())
                let remainder = name.hasSuffix("...")
                if remainder { name = String(name.dropLast(3)) }
                guard Self.validName(name), names.insert(name).inserted,
                    !remainder || index == path.count - 1
                else { throw LinkRuleError.invalidCapture }
                segments.append(remainder ? .remainder(name) : .capture(name))
                validationPath.append("capture")
            } else {
                guard !component.contains("{"), !component.contains("}"),
                    let literal = component.removingPercentEncoding, LinkURL.segment(literal)
                else {
                    throw LinkRuleError.invalidCapture
                }
                segments.append(.literal(literal))
                validationPath.append(component)
            }
        }
        guard LinkURL("\(scheme)://\(authority)/" + validationPath.joined(separator: "/")) != nil else {
            throw LinkRuleError.invalidPattern
        }
        guard !rule.labelTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            rule.labelTemplate.count <= 512, Self.safeText(rule.labelTemplate)
        else { throw LinkRuleError.invalidLabel }
        var label: [LabelPart] = []
        var remaining = rule.labelTemplate[...]
        while let open = remaining.firstIndex(of: "{") {
            let literal = String(remaining[..<open])
            guard !literal.contains("}"), let close = remaining[open...].firstIndex(of: "}") else {
                throw LinkRuleError.invalidLabel
            }
            let name = String(remaining[remaining.index(after: open)..<close])
            guard names.contains(name) else { throw LinkRuleError.invalidLabel }
            label.append(.literal(literal))
            label.append(.capture(name))
            remaining = remaining[remaining.index(after: close)...]
        }
        guard !remaining.contains("}") else { throw LinkRuleError.invalidLabel }
        label.append(.literal(String(remaining)))
        self.rule = rule
        self.scheme = scheme
        self.host = host
        self.port = url.port
        self.segments = segments
        self.label = label
    }

    func match(_ url: LinkURL, original: String) -> (match: LinkMatch, overridesBuiltIns: Bool)? {
        guard rule.enabled, scheme == url.scheme, host.lowercased() == url.host.lowercased(),
            port == url.components.port
        else {
            return nil
        }
        var captures: [String: String] = [:]
        var index = 0
        for segment in segments {
            guard index < url.parts.count else { return nil }
            switch segment {
            case .literal(let value):
                guard url.parts[index] == value else { return nil }
            case .capture(let name): captures[name] = url.parts[index]
            case .remainder(let name):
                captures[name] = url.parts[index...].joined(separator: "/")
                index = url.parts.count - 1
            }
            index += 1
        }
        guard index == url.parts.count else { return nil }
        var text = ""
        for part in label {
            switch part {
            case .literal(let value): text += value
            case .capture(let name): text += captures[name, default: ""]
            }
            guard text.utf8.count <= 8192 else { return nil }
        }
        return (
            LinkMatch(ruleName: rule.name, reference: Reference(original: original, label: text), captures: captures),
            rule.overridesBuiltIns
        )
    }

    private static func validName(_ name: String) -> Bool {
        let bytes = Array(name.utf8)
        return (1...32).contains(bytes.count)
            && bytes.enumerated().allSatisfy { index, byte in
                (65...90).contains(byte) || (97...122).contains(byte)
                    || (index > 0 && ((48...57).contains(byte) || byte == 95))
            }
    }

    private static func safeText(_ text: String) -> Bool {
        !text.unicodeScalars.contains {
            CharacterSet.controlCharacters.contains($0) || (0x202A...0x202E).contains($0.value)
                || (0x2066...0x2069).contains($0.value) || [0x200E, 0x200F, 0x061C].contains($0.value)
        }
    }
}
