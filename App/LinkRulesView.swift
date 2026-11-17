import PinkCore
import SwiftUI

/// Service bundles and individual patterns share one collection and the same controls.
/// Their storage stays intact so existing installations retain their matching behavior.
struct LinkRulesView: View {
    @ObservedObject var preferences: SettingsModel
    private var settings: PinkCore.Settings { preferences.value }
    @State private var editor: FormatEditor?
    @State private var example = ""
    @State private var removing: FormatEditor?
    @State private var error = ""
    @State private var added: AddedFormat?

    var body: some View {
        Form {
            introduction
            formats
            Section("Try a link") {
                LinkPreview(
                    hostRules: settings.rules, rules: settings.linkRules, example: $example,
                    createFormat: { editor = .builder($0) })
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.linkRules) { _, rules in
            if let added, rules != added.applied { self.added = nil }
        }
        .sheet(item: $editor) { selection in
            switch selection {
            case .builder(let example):
                LinkFormatBuilder(settings: settings, example: example) { updated in
                    var previous: [LinkRule] = []
                    var applied: [LinkRule] = []
                    try preferences.edit { value in
                        previous = value.linkRules
                        value.linkRules.removeAll { $0.id == updated.id }
                        value.linkRules.insert(updated, at: 0)
                        applied = value.linkRules
                    }
                    added = previous == applied ? nil : AddedFormat(rule: updated, previous: previous, applied: applied)
                }
            case .pattern(let rule):
                PatternEditor(settings: settings, initial: rule) { updated in
                    try preferences.edit { value in
                        if let index = value.linkRules.firstIndex(where: { $0.id == updated.id }) {
                            value.linkRules[index] = updated
                        } else {
                            value.linkRules.append(updated)
                        }
                    }
                }
            case .host(let index, let rule):
                HostFormatEditor(settings: settings, index: index, initial: rule) { updated in
                    try preferences.edit { value in
                        if let index {
                            try checkHost(index, rule, in: value)
                            value.rules[index] = updated
                        } else {
                            value.rules.append(updated)
                        }
                    }
                }
            }
        }
        .alert(
            "Couldn’t apply change",
            isPresented: Binding(
                get: { !error.isEmpty }, set: { if !$0 { error = "" } }
            )
        ) {
            Button("OK") { error = "" }
        } message: {
            Text(error)
        }
        .confirmationDialog(
            removing.map { "Remove \($0.name)?" } ?? "Remove format?",
            isPresented: Binding(
                get: { removing != nil }, set: { if !$0 { removing = nil } }
            ), titleVisibility: .visible, presenting: removing
        ) { selection in
            Button("Remove format", role: .destructive) {
                change { value in
                    switch selection {
                    case .builder: break
                    case .pattern(let rule): value.linkRules.removeAll { $0.id == rule.id }
                    case .host(let index, let rule):
                        if let index {
                            try checkHost(index, rule, in: value)
                            value.rules.remove(at: index)
                        }
                    }
                }
                removing = nil
            }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: { _ in
            Text("This removes the format and its settings. To keep it for later, turn it off instead.")
        }
    }

    private var introduction: some View {
        Section {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Link formats").font(.title2.bold())
                    Text("Choose how your links look when you paste.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Add format", systemImage: "plus") { editor = .builder("") }
                    .buttonStyle(.borderedProminent).fixedSize()
                Menu {
                    ForEach(LinkRule.templates) { template in
                        Button(template.name) { editor = .pattern(template) }
                    }
                    Divider()
                    Button("Other website…") {
                        editor = .pattern(LinkRule(name: "", urlPattern: "https://", labelTemplate: ""))
                    }
                    Button("GitHub or GitLab installation…") {
                        editor = .host(nil, HostRule(service: .github, host: ""))
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton).fixedSize()
                .accessibilityLabel("Advanced formats and installations")
            }
            .padding(.vertical, 8)
            if let added {
                HStack {
                    Label("\(added.rule.name) ready for future copies", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Undo") {
                        change { value in
                            guard value.linkRules == added.applied else { return }
                            value.linkRules = added.previous
                        }
                    }.buttonStyle(.link)
                }.font(.callout)
            }
        }
    }

    private var formats: some View {
        Section {
            ForEach(settings.rules.indices, id: \.self) { index in
                let rule = settings.rules[index]
                formatRow(
                    title: rule.service.displayName,
                    detail: rule.host + (rule.port.map { ":\($0)" } ?? "") + rule.basePath,
                    enabled: Binding(
                        get: {
                            preferences.value.rules.indices.contains(index)
                                ? preferences.value.rules[index].enabled : rule.enabled
                        },
                        set: { enabled in
                            change { value in
                                try checkHost(index, rule, in: value)
                                value.rules[index].enabled = enabled
                            }
                        }
                    ),
                    edit: { editor = .host(index, rule) }
                ) {
                    Button("Remove format…", role: .destructive) { removing = .host(index, rule) }
                }
            }
            ForEach(settings.linkRules) { rule in
                if let index = settings.linkRules.firstIndex(where: { $0.id == rule.id }) {
                    formatRow(
                        title: rule.name, detail: rule.urlPattern,
                        enabled: Binding(
                            get: {
                                preferences.value.linkRules.first { $0.id == rule.id }?.enabled ?? rule.enabled
                            },
                            set: { enabled in
                                change { value in
                                    guard let current = value.linkRules.firstIndex(where: { $0.id == rule.id })
                                    else {
                                        throw FormatEditError.changed
                                    }
                                    value.linkRules[current].enabled = enabled
                                }
                            }
                        ),
                        edit: { editor = .pattern(rule) }
                    ) {
                        Button("Move earlier", systemImage: "arrow.up") {
                            movePattern(rule.id, by: -1)
                        }.disabled(index == 0)
                        Button("Move later", systemImage: "arrow.down") {
                            movePattern(rule.id, by: 1)
                        }.disabled(index == settings.linkRules.count - 1)
                        Divider()
                        Button("Remove format…", role: .destructive) { removing = .pattern(rule) }
                    }
                }
            }
            if settings.rules.isEmpty && settings.linkRules.isEmpty {
                ContentUnavailableView(
                    "Add your first format", systemImage: "link",
                    description: Text("Add a format to turn long URLs into readable links."))
            }
        } header: {
            Text("Your formats")
        } footer: {
            Text("Changes apply immediately. Turn a format off to stop using it for new copies.")
        }
    }

    private func change(_ edit: (inout PinkCore.Settings) throws -> Void) {
        do { try preferences.edit(edit) } catch is ValidationError {
            error =
                "Another enabled website format covers this hostname and installation path. Edit it before enabling this format."
        } catch {
            self.error = "Your previous settings are still active. Try again."
        }
    }

    private func movePattern(_ id: UUID, by offset: Int) {
        change { value in
            guard let index = value.linkRules.firstIndex(where: { $0.id == id }),
                value.linkRules.indices.contains(index + offset)
            else { return }
            value.linkRules.swapAt(index, index + offset)
        }
    }

    private func checkHost(_ index: Int, _ original: HostRule, in value: PinkCore.Settings) throws {
        guard value.rules.indices.contains(index), value.rules[index] == original else {
            throw FormatEditError.changed
        }
    }

    private func formatRow<Actions: View>(
        title: String, detail: String, enabled: Binding<Bool>, edit: @escaping () -> Void,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.title3).foregroundStyle(.tint)
                .frame(width: 32, height: 32)
                .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            Button(action: edit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).fontWeight(.medium).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(title), \(detail)")
            Toggle("Enable \(title), \(detail)", isOn: enabled)
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
            Menu {
                Button("Edit…", action: edit)
                actions()
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton).fixedSize()
            .accessibilityLabel("Options for \(title), \(detail)")
        }
        .padding(.vertical, 4)
    }
}

private struct AddedFormat {
    let rule: LinkRule
    let previous: [LinkRule]
    let applied: [LinkRule]
}

private enum FormatEditError: Error { case changed }

private enum FormatEditor: Identifiable {
    case builder(String)
    case pattern(LinkRule)
    case host(Int?, HostRule)
    var name: String {
        switch self {
        case .builder: "New format"
        case .pattern(let rule): rule.name
        case .host(_, let rule): "\(rule.service.displayName) at \(rule.host)"
        }
    }
    var id: String {
        switch self {
        case .builder: "builder"
        case .pattern(let rule): "pattern-\(rule.id)"
        case .host(let index, _): "host-\(index ?? -1)"
        }
    }
}

extension Service {
    var displayName: String { self == .github ? "GitHub" : "GitLab" }
}

struct LinkPreview: View {
    let hostRules: [HostRule]
    let rules: [LinkRule]
    @Binding var example: String
    var isValid = true
    var createFormat: ((String) -> Void)?
    private var matches: [LinkMatch] {
        (try? Parser(rules: hostRules, linkRules: rules))?.matches(example) ?? []
    }

    var body: some View {
        let results = matches
        TextField("Example URL", text: $example, prompt: Text("Paste a URL to see how it will look"))
            .textContentType(.URL).autocorrectionDisabled()
        if !isValid && !example.isEmpty {
            Text("Finish the format above to preview this link.").foregroundStyle(.secondary)
        } else if let winner = results.first, let destination = URL(string: winner.reference.original) {
            HStack {
                Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary)
                Link(winner.reference.label, destination: destination)
                    .accessibilityLabel("Preview: \(winner.reference.label)")
                    .textSelection(.enabled)
            }.padding(.vertical, 4)
            DisclosureGroup("Matched by \(winner.ruleName)") {
                ForEach(winner.captures.keys.sorted(), id: \.self) { key in
                    Text("\(key) = \(winner.captures[key, default: ""])").font(.caption.monospaced())
                }
                if results.count > 1 {
                    Text(
                        "Also matches: \(results.dropFirst().map(\.ruleName).joined(separator: ", ")). The first match wins."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        } else if !example.isEmpty {
            Label("This link doesn’t have a format yet.", systemImage: "link")
                .foregroundStyle(.secondary)
            if let createFormat, (try? LinkSuggestion(example)) != nil {
                Button("Make a format for this link") { createFormat(example) }
                    .buttonStyle(.link)
            }
        }
        Text("Only used for this preview. Never saved.").font(.caption).foregroundStyle(.secondary)
    }
}

struct PatternEditor: View {
    let settings: PinkCore.Settings
    @State private var draft: LinkRule
    @State private var example: String
    @State private var saveError = ""
    @State private var hasEdited = false
    @FocusState private var primaryFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    let save: (LinkRule) throws -> Void

    init(
        settings: PinkCore.Settings, initial: LinkRule, example: String = "", save: @escaping (LinkRule) throws -> Void
    ) {
        self.settings = settings
        _draft = State(initialValue: initial)
        _example = State(initialValue: example)
        self.save = save
    }

    private var isEditing: Bool { settings.linkRules.contains { $0.id == draft.id } }
    private var proposed: [LinkRule] {
        var rules = settings.linkRules
        if let index = rules.firstIndex(where: { $0.id == draft.id }) {
            rules[index] = draft
        } else {
            rules.append(draft)
        }
        return rules
    }
    private var validation: String? {
        do {
            _ = try Parser(rules: settings.rules, linkRules: proposed)
            return nil
        } catch let error as LinkRuleError {
            return error.localizedDescription
        } catch {
            return "Check the hostname and scheme. Public GitHub and GitLab links require HTTPS."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $draft.name, prompt: Text("e.g. Team wiki"))
                        .focused($primaryFieldFocused)
                    TextField("URL pattern", text: $draft.urlPattern).textContentType(.URL).autocorrectionDisabled()
                    TextField("Link label", text: $draft.labelTemplate).autocorrectionDisabled()
                } header: {
                    Text(isEditing ? "Edit link format" : "Add link format").font(.title2.bold())
                } footer: {
                    Text(
                        "Use {name} for a path segment, or {path...} for the rest of a URL. Include {name} or {path} in your label."
                    )
                }
                Section("Try a link") {
                    LinkPreview(
                        hostRules: settings.rules, rules: proposed, example: $example, isValid: validation == nil)
                }
                DisclosureGroup("Advanced") {
                    Toggle("Prefer over matching website formats", isOn: $draft.overridesBuiltIns)
                    Text(
                        "When formats overlap, preferred patterns run first, then website formats, then other patterns in list order."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    Toggle("Enable format", isOn: $draft.enabled)
                    if draft.urlPattern.lowercased().hasPrefix("http://") {
                        Text("This pattern allows unencrypted HTTP for this host.").font(.caption)
                    }
                }
                if let validation, isEditing || hasEdited {
                    Label(validation, systemImage: "exclamationmark.circle")
                        .font(.callout).foregroundStyle(.red)
                }
            }.formStyle(.grouped)
            editorButtons(title: isEditing ? "Done" : "Add format", disabled: validation != nil) {
                do {
                    try save(draft)
                    dismiss()
                } catch { saveError = "Couldn’t save this format. Your draft is still here. Try again." }
            } cancel: {
                dismiss()
            }
        }
        .onChange(of: draft) { _, _ in hasEdited = true }
        .defaultFocus($primaryFieldFocused, true)
        .frame(minWidth: 560, idealWidth: 560, minHeight: 580, idealHeight: 580)
        .alert(
            "Couldn’t save format",
            isPresented: Binding(
                get: { !saveError.isEmpty }, set: { if !$0 { saveError = "" } }
            )
        ) {
            Button("OK") { saveError = "" }
        } message: {
            Text(saveError)
        }
    }
}

private struct HostFormatEditor: View {
    let settings: PinkCore.Settings
    let index: Int?
    @State private var draft: HostRule
    @State private var port: String
    @State private var example = ""
    @State private var saveError = ""
    @State private var hasEdited = false
    @FocusState private var primaryFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    let save: (HostRule) throws -> Void

    init(settings: PinkCore.Settings, index: Int?, initial: HostRule, save: @escaping (HostRule) throws -> Void) {
        self.settings = settings
        self.index = index
        _draft = State(initialValue: initial)
        _port = State(initialValue: initial.port.map(String.init) ?? "")
        self.save = save
    }
    private var candidate: HostRule {
        var rule = draft
        rule.port = Int(port)
        return rule
    }
    private var proposed: [HostRule] {
        var rules = settings.rules
        if let index { rules[index] = candidate } else { rules.append(candidate) }
        return rules
    }
    private var validation: String? {
        guard port.isEmpty || Int(port) != nil else { return "Enter a port from 1 to 65535, or leave it empty." }
        do {
            _ = try Parser(rules: proposed, linkRules: settings.linkRules)
            return nil
        } catch {
            return "Use an exact hostname and a unique installation path. Check the port and any overlapping formats."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Website", selection: $draft.service) {
                        ForEach(Service.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    TextField("Hostname", text: $draft.host, prompt: Text("git.example.com"))
                        .autocorrectionDisabled()
                        .focused($primaryFieldFocused)
                    Text(
                        draft.service == .github
                            ? "Formats repositories, issues, pull requests, files and releases."
                            : "Formats issues and merge requests, including nested groups."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                } header: {
                    Text(index == nil ? "Add website format" : "Edit website format").font(.title2.bold())
                }
                Section("Try a link") {
                    LinkPreview(
                        hostRules: proposed, rules: settings.linkRules, example: $example, isValid: validation == nil)
                }
                DisclosureGroup("Advanced") {
                    TextField("Port (optional)", text: $port)
                    TextField("Installation path (optional)", text: $draft.basePath, prompt: Text("/git"))
                    Toggle("Allow HTTP for this host", isOn: $draft.allowHTTP)
                    Toggle("Enable format", isOn: $draft.enabled)
                }
                if let validation, index != nil || hasEdited {
                    Label(validation, systemImage: "exclamationmark.circle")
                        .font(.callout).foregroundStyle(.red)
                }
            }.formStyle(.grouped)
            editorButtons(title: index == nil ? "Add format" : "Done", disabled: validation != nil) {
                do {
                    try save(candidate)
                    dismiss()
                } catch { saveError = "Couldn’t save this format. Your draft is still here. Try again." }
            } cancel: {
                dismiss()
            }
        }
        .onChange(of: draft) { _, _ in hasEdited = true }
        .onChange(of: port) { _, _ in hasEdited = true }
        .defaultFocus($primaryFieldFocused, true)
        .frame(minWidth: 560, idealWidth: 560, minHeight: 580, idealHeight: 580)
        .alert(
            "Couldn’t save format",
            isPresented: Binding(
                get: { !saveError.isEmpty }, set: { if !$0 { saveError = "" } }
            )
        ) {
            Button("OK") { saveError = "" }
        } message: {
            Text(saveError)
        }
    }
}

@MainActor private func editorButtons(
    title: String, disabled: Bool, save: @escaping () -> Void, cancel: @escaping () -> Void
)
    -> some View
{
    VStack(spacing: 0) {
        Divider()
        HStack {
            Spacer()
            Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
            Button(title, action: save).keyboardShortcut(.defaultAction).disabled(disabled)
        }.padding()
    }
}
