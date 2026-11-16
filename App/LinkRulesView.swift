import PinkCore
import SwiftUI

struct LinkRulesView: View {
    let hostRules: [HostRule]
    @Binding var rules: [LinkRule]
    @State private var draft = LinkRule.templates[0]
    @State private var editing: UUID?
    @State private var example = ""
    @State private var notice = ""

    init(
        hostRules: [HostRule], rules: Binding<[LinkRule]>, initialDraft: LinkRule = LinkRule.templates[0],
        example: String = ""
    ) {
        self.hostRules = hostRules
        _rules = rules
        _draft = State(initialValue: initialDraft)
        _example = State(initialValue: example)
    }

    private var proposedRules: [LinkRule] {
        var proposed = rules
        if let index = proposed.firstIndex(where: { $0.id == editing }) {
            proposed[index] = draft
        } else {
            proposed.append(draft)
        }
        return proposed
    }

    private var validation: String? {
        do {
            _ = try Parser(rules: hostRules, linkRules: proposedRules)
            return nil
        } catch let error as LinkRuleError { return error.localizedDescription } catch {
            return "Check the service presets in General settings."
        }
    }

    private var matches: [LinkMatch] {
        (try? Parser(rules: hostRules, linkRules: proposedRules))?.matches(example) ?? []
    }

    var body: some View {
        Form {
            Section("Custom link formats") {
                Text(
                    "GitHub and GitLab presets are active for enabled hosts in General. Custom rules are tried from top to bottom; the first matching rule wins."
                )
                .font(.caption).foregroundStyle(.secondary)
                if rules.isEmpty { Text("No custom formats yet.").foregroundStyle(.secondary) }
                ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                    HStack {
                        Toggle(rule.name, isOn: $rules[index].enabled)
                        Spacer()
                        Button("Up") { rules.swapAt(index, index - 1) }.disabled(index == 0)
                            .accessibilityLabel("Move \(rule.name) up")
                        Button("Down") { rules.swapAt(index, index + 1) }.disabled(index == rules.count - 1)
                            .accessibilityLabel("Move \(rule.name) down")
                        Button("Edit") {
                            draft = rule
                            editing = rule.id
                            notice = ""
                        }.accessibilityLabel("Edit \(rule.name)")
                        Button("Remove") {
                            rules.removeAll { $0.id == rule.id }
                            if editing == rule.id { reset() }
                        }.accessibilityLabel("Remove \(rule.name)")
                    }
                }
            }
            Section(editing == nil ? "Build a link format" : "Edit link format") {
                Menu("Start from a preset") {
                    ForEach(LinkRule.templates) { template in
                        Button(template.name) {
                            draft = template
                            editing = nil
                            notice = ""
                        }
                    }
                }
                TextField("Name", text: $draft.name)
                TextField("URL pattern", text: $draft.urlPattern)
                    .textContentType(.URL)
                TextField("Link label", text: $draft.labelTemplate)
                Text(
                    "{issue} captures one path segment. {path...} captures the rest at the end. Use {path} in the label. Queries and fragments stay in the destination."
                )
                .font(.caption).foregroundStyle(.secondary)
                Toggle("Override matching service presets", isOn: $draft.overridesBuiltIns)
                Toggle("Enable this rule", isOn: $draft.enabled)
                if draft.urlPattern.lowercased().hasPrefix("http://") {
                    Text("This pattern explicitly allows HTTP for this host.").font(.caption)
                }
                if let validation { Text(validation).foregroundStyle(.red).accessibilityLabel(validation) }
                HStack {
                    Button(editing == nil ? "Add to settings" : "Update rule") {
                        rules = proposedRules
                        reset()
                        notice = "Rule updated. Save settings to apply."
                    }.disabled(validation != nil)
                    Button("New rule") { reset() }
                    if !notice.isEmpty { Text(notice).font(.caption) }
                }
            }
            Section("Live preview") {
                TextField("Example URL", text: $example)
                    .textContentType(.URL)
                if let winner = matches.first {
                    if let destination = URL(string: winner.reference.original) {
                        Link(destination: destination) {
                            Text(winner.reference.label).textSelection(.enabled)
                        }.accessibilityLabel("Preview: \(winner.reference.label)")
                    }
                    Text("Matched: \(winner.ruleName)").font(.caption)
                    ForEach(winner.captures.keys.sorted(), id: \.self) { key in
                        Text("\(key) = \(winner.captures[key, default: ""])").font(.caption.monospaced())
                    }
                    if matches.count > 1 {
                        Text(
                            "Also matches: \(matches.dropFirst().map(\.ruleName).joined(separator: ", ")). The first match above wins."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                } else if !example.isEmpty && validation == nil {
                    Text("No enabled rule matches. This URL will stay unchanged.").foregroundStyle(.secondary)
                } else {
                    Text("Try an example to preview the draft and your other enabled formats.").foregroundStyle(
                        .secondary)
                }
                Text("Example URLs are used only for this preview and are never saved.").font(.caption)
            }
        }.formStyle(.grouped)
    }

    private func reset() {
        draft = LinkRule.templates[0]
        editing = nil
        notice = ""
    }
}
