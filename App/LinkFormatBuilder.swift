import PinkCore
import SwiftUI

/// Starts with a real link. Pattern syntax is available without being a prerequisite.
struct LinkFormatBuilder: View {
    let settings: PinkCore.Settings
    let save: (LinkRule) throws -> Void
    @State private var example: String
    @State private var selection: Int?
    @State private var includeContext = false
    @State private var customizing = false
    @State private var manual: LinkRule?
    @State private var saveError = ""
    @State private var ruleID = UUID()
    @FocusState private var exampleFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(settings: PinkCore.Settings, example: String = "", save: @escaping (LinkRule) throws -> Void) {
        self.settings = settings
        self.save = save
        _example = State(initialValue: example)
        let suggestion = try? LinkSuggestion(example)
        _selection = State(initialValue: suggestion?.defaultSelection)
        _includeContext = State(initialValue: suggestion?.defaultIncludesContext ?? false)
    }

    private var suggestion: LinkSuggestion? { try? LinkSuggestion(example) }
    private var suggestionError: String {
        do {
            _ = try LinkSuggestion(example)
            return ""
        } catch let error as LocalizedError { return error.errorDescription ?? "Check this link." } catch {
            return "Check this link’s hostname and path."
        }
    }
    private var existing: Reference? {
        (try? Parser(rules: settings.rules, linkRules: settings.linkRules))?.parse(example)
    }
    private var alreadyWorks: Bool { existing != nil && !customizing }
    private var candidate: LinkRule? {
        if let manual { return manual }
        guard var rule = try? suggestion?.rule(selection: selection, includeContext: includeContext, id: ruleID) else {
            return nil
        }
        rule.overridesBuiltIns = customizing
        if let previous = settings.linkRules.first(where: { $0.urlPattern == rule.urlPattern && $0.enabled }) {
            rule.id = previous.id
            rule.name = previous.name
            rule.overridesBuiltIns = previous.overridesBuiltIns || customizing
        }
        return rule
    }
    private var proposed: [LinkRule] {
        var rules = settings.linkRules
        guard let candidate else { return rules }
        if let index = rules.firstIndex(where: { $0.id == candidate.id }) {
            rules[index] = candidate
        } else {
            rules.insert(candidate, at: 0)
        }
        return rules
    }
    private var validation: String? {
        guard candidate != nil else { return "Paste a complete web link to get started." }
        do {
            _ = try Parser(rules: settings.rules, linkRules: proposed)
            return nil
        } catch let error as LocalizedError { return error.errorDescription } catch {
            return "Check this format’s hostname and pattern."
        }
    }
    private var preview: Reference? {
        if alreadyWorks { return existing }
        guard validation == nil else { return nil }
        return (try? Parser(rules: settings.rules, linkRules: proposed))?.parse(example)
    }
    private var actionTitle: String {
        if alreadyWorks { return "Done" }
        return suggestion?.siteName == "Jira" ? "Use for Jira links" : "Use this format"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Make a link format").font(.title2.weight(.semibold))
                        Text("Start with a link you already use.").foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Example link").font(.callout.weight(.medium))
                        TextField("https://…", text: $example)
                            .textContentType(.URL).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                            .focused($exampleFocused).accessibilityIdentifier("builder-example")
                        HStack(spacing: 12) {
                            Text("Try").foregroundStyle(.secondary)
                            exampleButton("Jira ticket", "https://jira.example/browse/ACME-184273")
                            exampleButton("Pull request", "https://github.com/acme/widget/pull/123")
                            exampleButton(
                                "Repository file", "https://github.com/acme/widget/blob/main/Sources/App.swift#L10-L20")
                        }.font(.caption)
                    }
                    if alreadyWorks {
                        Label("This link is already ready to paste.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                        Button("Choose a different look") { customizing = true }
                            .buttonStyle(.link)
                    } else if let suggestion {
                        choices(suggestion)
                    } else if !example.isEmpty {
                        Label(suggestionError, systemImage: "link")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if let preview {
                        previewCard(preview)
                    } else if candidate != nil, !example.isEmpty {
                        Label(
                            validation ?? "This format doesn’t match the example yet.",
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.callout).foregroundStyle(.secondary)
                    }
                    if candidate != nil, !alreadyWorks { advanced }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Text(alreadyWorks ? "Your existing format is active" : "Applies to future copies")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(actionTitle) {
                    if alreadyWorks {
                        dismiss()
                        return
                    }
                    guard let candidate else { return }
                    do {
                        try save(candidate)
                        dismiss()
                    } catch { saveError = "Couldn’t save this format. Your draft is still here. Try again." }
                }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .disabled(!alreadyWorks && (validation != nil || preview == nil))
                .accessibilityIdentifier("builder-use-format")
            }.padding(20)
        }
        .tint(.pink)
        .frame(minWidth: 580, idealWidth: 620, minHeight: 600, idealHeight: 660)
        .defaultFocus($exampleFocused, true)
        .onChange(of: example) { _, _ in
            let suggestion = try? LinkSuggestion(example)
            selection = suggestion?.defaultSelection
            includeContext = suggestion?.defaultIncludesContext ?? false
            manual = nil
            customizing = false
        }
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

    private func exampleButton(_ title: String, _ value: String) -> some View {
        Button(title) { example = value }.buttonStyle(.link)
    }

    private func choices(_ suggestion: LinkSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keep the part you care about").font(.callout.weight(.medium))
            Text(suggestion.host).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            // An adaptive grid keeps long paths and keyboard targets within the window.
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 8
            ) {
                ForEach(suggestion.parts.indices, id: \.self) { index in
                    Button {
                        selection = index
                        manual = nil
                    } label: {
                        Text(suggestion.parts[index]).lineLimit(2).truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6).padding(.horizontal, 10)
                            .background(
                                selection == index ? Color.pink.opacity(0.1) : Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .foregroundStyle(selection == index ? Color.pink : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(suggestion.parts[index]) as link text")
                    .accessibilityAddTraits(selection == index ? .isSelected : [])
                }
            }
            if !suggestion.parts.isEmpty {
                Text(
                    suggestion.siteName == "GitHub" && selection == suggestion.defaultSelection
                        ? "Future links can use different owners and repositories."
                        : "The highlighted part can change. Other path parts stay fixed."
                )
                .font(.caption).foregroundStyle(.secondary)
                Toggle(
                    suggestion.siteName == "Jira"
                        ? "Include ‘Jira’ in the label" : "Include website or repository context",
                    isOn: $includeContext
                )
                .onChange(of: includeContext) { _, _ in manual = nil }
                .font(.callout)
            }
        }
    }

    private func previewCard(_ reference: Reference) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste preview").font(.caption).foregroundStyle(.secondary)
            if let destination = URL(string: reference.original) {
                Link(reference.label, destination: destination)
                    .font(.title2.weight(.medium)).textSelection(.enabled)
                    .accessibilityIdentifier("builder-preview")
            }
            Label(reference.original, systemImage: "link")
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                .lineLimit(3).truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(Color.pink.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var advanced: some View {
        DisclosureGroup("Advanced pattern") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Format name", text: field(\.name, fallback: "")).textFieldStyle(.roundedBorder)
                TextField("URL pattern", text: field(\.urlPattern, fallback: ""))
                    .textFieldStyle(.roundedBorder).autocorrectionDisabled()
                TextField("Link label", text: field(\.labelTemplate, fallback: ""))
                    .textFieldStyle(.roundedBorder).autocorrectionDisabled()
                Toggle("Prefer over matching formats", isOn: field(\.overridesBuiltIns, fallback: false))
                Text("{name} captures a path segment. A final {path...} captures the rest; use {path} in the label.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 12)
        }.font(.callout)
    }

    private func field<Value>(_ keyPath: WritableKeyPath<LinkRule, Value>, fallback: Value) -> Binding<Value> {
        Binding(
            get: { candidate?[keyPath: keyPath] ?? fallback },
            set: { value in
                guard var updated = candidate else { return }
                updated[keyPath: keyPath] = value
                manual = updated
            })
    }
}
