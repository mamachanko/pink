import Foundation

/// Presentation hints derived locally from conventional routes, never remote status.
enum LinkKind: Sendable {
    case repository, issue, review, file, release, commit, workflow, run, job, jira

    var icon: String {
        switch self {
        case .repository: "📦"
        case .issue: "📋"
        case .review: "🔀"
        case .file: "📄"
        case .release: "🏷️"
        case .commit: "🔖"
        case .workflow: "⚙️"
        case .run: "▶️"
        case .job: "🛠️"
        case .jira: "🎫"
        }
    }

    func decorate(_ reference: Reference) -> Reference {
        // Keep an explicitly authored leading emoji rather than adding another.
        if reference.label.first?.unicodeScalars.contains(where: {
            $0.properties.isEmojiPresentation || $0.value == 0xFE0F
        }) == true {
            return reference
        }
        return Reference(original: reference.original, label: icon + " " + reference.label)
    }

    static func jira(in url: LinkURL) -> LinkKind? {
        guard !["github.com", "gitlab.com"].contains(url.host.lowercased()), url.parts.count >= 2,
            url.parts[url.parts.count - 2] == "browse", LinkSuggestion.isIssueKey(url.parts.last!)
        else { return nil }
        return .jira
    }
}
