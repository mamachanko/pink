import Foundation

/// In-memory editing state; only `candidate` can be saved, never the example.
public struct LinkBuilderDraft {
    public private(set) var example: String
    public private(set) var selection: Int?
    public private(set) var includeContext = false
    public private(set) var usesCustomPattern = false
    public private(set) var allowHTTP = false
    public private(set) var candidate: LinkRule?
    private var customizing = false
    private var editedName: String?
    private var editedPriority: Bool?
    private let ruleID = UUID()

    public init(example: String = "", settings: Settings) {
        self.example = example
        useSuggestion(settings: settings)
        customizing = false
    }

    public var suggestion: LinkSuggestion? { try? LinkSuggestion(example) }

    public func alreadyWorks(in settings: Settings) -> Bool {
        !customizing && existing(in: settings) != nil
    }

    public func preview(in settings: Settings) -> Reference? {
        if alreadyWorks(in: settings) { return existing(in: settings) }
        guard validation(in: settings) == nil else { return nil }
        return (try? Parser(rules: settings.rules, linkRules: proposed(in: settings)))?.parse(example)
    }

    public func validation(in settings: Settings) -> String? {
        guard let candidate else { return "Paste a complete web link to get started." }
        do {
            _ = try Parser(rules: settings.rules, linkRules: proposed(in: settings))
            if try Parser(rules: [], linkRules: [candidate]).parse(example) == nil {
                return "This pattern doesn’t match the example link yet."
            }
            return nil
        } catch let error as LocalizedError { return error.errorDescription } catch {
            return "Check this format’s hostname and pattern."
        }
    }

    public func canFinish(in settings: Settings) -> Bool {
        alreadyWorks(in: settings)
            || (validation(in: settings) == nil && preview(in: settings) != nil && (!usesHTTP || allowHTTP))
    }

    public var usesHTTP: Bool { LinkURL(example)?.scheme == "http" }

    public mutating func updateExample(_ value: String, settings: Settings) {
        let oldEndpoint = endpoint
        example = value
        if endpoint != oldEndpoint { allowHTTP = false }
        // Typing or testing another URL must not silently replace a crafted pattern.
        guard !usesCustomPattern, suggestion != nil else { return }
        if let candidate, (try? Parser(rules: [], linkRules: [candidate]).parse(example)) != nil { return }
        useSuggestion(settings: settings)
    }

    public mutating func customize() {
        customizing = true
        if editedPriority == nil { candidate?.overridesBuiltIns = true }
    }

    public mutating func choosePart(_ index: Int, settings: Settings) {
        customizing = true
        selection = index
        regenerate(settings: settings)
    }

    public mutating func setContext(_ value: Bool, settings: Settings) {
        customizing = true
        includeContext = value
        regenerate(settings: settings)
    }

    public mutating func useSuggestion(settings: Settings) {
        selection = suggestion?.defaultSelection
        includeContext = suggestion?.defaultIncludesContext ?? false
        regenerate(settings: settings)
    }

    public mutating func approveHTTP(_ value: Bool) { allowHTTP = value }

    public mutating func edit<Value>(
        _ keyPath: WritableKeyPath<LinkRule, Value>, to value: Value
    ) {
        guard candidate != nil else { return }
        customizing = true
        candidate?[keyPath: keyPath] = value
        if keyPath == \LinkRule.name { editedName = candidate?.name }
        if keyPath == \LinkRule.overridesBuiltIns { editedPriority = candidate?.overridesBuiltIns }
        if keyPath == \LinkRule.urlPattern || keyPath == \LinkRule.labelTemplate { usesCustomPattern = true }
    }

    private var endpoint: String? {
        guard let url = LinkURL(example) else { return nil }
        return "\(url.scheme)://\(url.host.lowercased()):\(url.components.port.map(String.init) ?? "")"
    }

    private func existing(in settings: Settings) -> Reference? {
        (try? Parser(rules: settings.rules, linkRules: settings.linkRules))?.parse(example)
    }

    private func proposed(in settings: Settings) -> [LinkRule] {
        guard let candidate else { return settings.linkRules }
        return [candidate] + settings.linkRules.filter { $0.id != candidate.id }
    }

    private mutating func regenerate(settings: Settings) {
        guard var rule = try? suggestion?.rule(selection: selection, includeContext: includeContext, id: ruleID) else {
            return
        }
        if let previous = settings.linkRules.first(where: { $0.urlPattern == rule.urlPattern && $0.enabled }) {
            rule.id = previous.id
            rule.name = previous.name
            rule.overridesBuiltIns = previous.overridesBuiltIns
        }
        if let editedName { rule.name = editedName }
        rule.overridesBuiltIns = editedPriority ?? (rule.overridesBuiltIns || customizing)
        candidate = rule
        usesCustomPattern = false
    }
}
