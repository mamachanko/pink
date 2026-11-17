import Foundation

/// Ephemeral input for the visual builder. Only the resulting rule enters settings.
public struct LinkSuggestion: Equatable, Sendable {
    public let original: String
    public let host: String
    public let parts: [String]
    public let siteName: String
    public let defaultSelection: Int?
    public let defaultIncludesContext: Bool
    private let origin: String
    private let path: [String]
    private let kind: Kind
    private enum Kind: Equatable, Sendable {
        case jira, githubNumber, githubRepository, githubFile, githubRelease, other
    }

    public init(_ example: String) throws {
        guard let url = LinkURL(example) else { throw LinkSuggestionError.invalidURL }
        if url.scheme == "http", ["github.com", "gitlab.com"].contains(url.host.lowercased()) {
            throw LinkSuggestionError.requiresHTTPS
        }
        let authority = example[example.range(of: "://")!.upperBound...].prefix { !"/?#".contains($0) }
        original = example
        host = String(authority)
        origin = url.scheme + "://" + authority
        path = url.parts
        var choices = url.parts
        let knownGitHub = url.host.lowercased() == "github.com" && (try? Parser().parse(example)) != nil
        let kind: Kind
        let selected: Int?
        let site: String
        if choices.count >= 2, choices[choices.count - 2] == "browse" {
            kind = .jira
            selected = choices.count - 1
            site = "Jira"
        } else if knownGitHub, choices.count >= 4,
            ["pull", "issues"].contains(choices[2])
        {
            kind = .githubNumber
            selected = 3
            site = "GitHub"
        } else if knownGitHub, choices.count == 2 {
            kind = .githubRepository
            selected = 1
            site = "GitHub"
        } else if knownGitHub, choices.count >= 5, choices[2] == "blob" {
            kind = .githubFile
            choices = Array(choices.prefix(3)) + [choices.dropFirst(3).joined(separator: "/")]
            selected = 3
            site = "GitHub"
        } else if knownGitHub, choices.count >= 5,
            choices[2] == "releases", choices[3] == "tag"
        {
            kind = .githubRelease
            choices = Array(choices.prefix(4)) + [choices.dropFirst(4).joined(separator: "/")]
            selected = 4
            site = "GitHub"
        } else {
            kind = .other
            selected = choices.indices.last
            site = url.host.lowercased() == "gitlab.com" ? "GitLab" : url.host
        }
        self.kind = kind
        parts = choices
        siteName = site
        defaultSelection = selected
        defaultIncludesContext = [.githubNumber, .githubRepository, .githubFile, .githubRelease].contains(kind)
        // Reject unsupported endpoints and unrepresentable patterns before showing a suggestion.
        _ = try rule(selection: selected, includeContext: defaultIncludesContext)
    }

    public func rule(selection: Int?, includeContext: Bool, id: UUID = UUID()) throws -> LinkRule {
        guard selection.map({ parts.indices.contains($0) }) ?? parts.isEmpty else {
            throw LinkSuggestionError.invalidSelection
        }
        var pattern = path.map(Self.encode)
        let label: String
        var name = siteName + " links"
        if selection == defaultSelection {
            switch kind {
            case .jira:
                pattern[selection!] = "{issue}"
                label = includeContext ? "Jira · {issue}" : "{issue}"
                name = "Jira issues"
            case .githubNumber:
                pattern[0] = "{owner}"
                pattern[1] = "{repo}"
                pattern[3] = "{number}"
                label = includeContext ? "{owner}/{repo}#{number}" : "{number}"
                name = path[2] == "pull" ? "GitHub pull requests" : "GitHub issues"
            case .githubRepository:
                pattern = ["{owner}", "{repo}"]
                label = includeContext ? "{owner}/{repo}" : "{repo}"
                name = "GitHub repositories"
            case .githubFile:
                pattern = ["{owner}", "{repo}", "blob", "{path...}"]
                label = includeContext ? "{owner}/{repo} · {path}" : "{path}"
                name = "GitHub files"
            case .githubRelease:
                pattern = ["{owner}", "{repo}", "releases", "tag", "{tag...}"]
                label = includeContext ? "{owner}/{repo}@{tag}" : "{tag}"
                name = "GitHub releases"
            case .other:
                if let selection { pattern[selection] = "{part}" }
                label = selection == nil ? host : includeContext ? siteName + " · {part}" : "{part}"
            }
        } else {
            // A grouped file path or release tag is a remainder, never a guessed ref boundary.
            pattern = parts.enumerated().map { index, value in
                if index == selection {
                    return value.contains("/") ? "{part...}" : "{part}"
                }
                return value.split(separator: "/").map { Self.encode(String($0)) }.joined(separator: "/")
            }
            label = includeContext ? siteName + " · {part}" : "{part}"
        }
        let rule = LinkRule(
            id: id, name: String(name.prefix(80)), urlPattern: origin + "/" + pattern.joined(separator: "/"),
            labelTemplate: label)
        guard rule.urlPattern.utf8.count <= 2048 else { throw LinkSuggestionError.patternTooLong }
        guard let reference = try Parser(rules: [], linkRules: [rule]).parse(original), !reference.label.isEmpty else {
            throw LinkSuggestionError.invalidURL
        }
        return rule
    }

    private static func encode(_ part: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%?#{}"))
        return part.addingPercentEncoding(withAllowedCharacters: allowed)!
    }
}

public enum LinkSuggestionError: String, Error, LocalizedError {
    case invalidURL = "Paste a complete HTTP(S) link without credentials."
    case invalidSelection = "Choose a part of this link."
    case requiresHTTPS = "Use HTTPS for public GitHub and GitLab links."
    case patternTooLong = "This link’s path is too long for a saved format. Try a shorter example."
    public var errorDescription: String? { rawValue }
}
