import XCTest

@testable import PinkCore

final class ActionsLinkTests: XCTestCase {
    private let revision = "b4b5edb2fea0da48684c39f517902ca6851fe523"

    func testReportedURLsAndEightCharacterRevisions() throws {
        let parser = try Parser()
        for (url, label) in [
            ("https://github.com/mamachanko/pink/pull/34", "mamachanko/pink#34"),
            ("https://github.com/mamachanko/pink/issues/28", "mamachanko/pink#28"),
            (
                "https://github.com/mamachanko/pink/blob/main/.github/workflows/ci.yml",
                "mamachanko/pink · main/.github/workflows/ci.yml"
            ),
            (
                "https://github.com/mamachanko/pink/actions/runs/44518099853/job/135539289334",
                "mamachanko/pink · job 135539289334"
            ),
            ("https://github.com/mamachanko/pink/actions/runs/44518099853", "mamachanko/pink · run 44518099853"),
            ("https://github.com/mamachanko/pink/actions/workflows/ci.yml", "mamachanko/pink · ci.yml"),
            (
                "https://github.com/mamachanko/pink/blob/\(revision)/.github/workflows/ci.yml",
                "mamachanko/pink · b4b5edb2/.github/workflows/ci.yml"
            ),
            ("https://github.com/mamachanko/pink/commit/\(revision)", "mamachanko/pink@b4b5edb2"),
        ] {
            let reference = try XCTUnwrap(parser.parse(url), url)
            XCTAssertEqual(reference.label, label)
            XCTAssertEqual(reference.original, url)
        }
    }

    func testDefaultApplicationIconsDistinguishConventionalKinds() throws {
        var settings = Settings()
        settings.linkRules = [LinkRule.templates[0]]
        let parser = try Parser(settings: settings)
        for (url, label) in [
            ("https://github.com/acme/widget", "📦 acme/widget"),
            ("https://github.com/acme/widget/issues/28", "📋 acme/widget#28"),
            ("https://github.com/acme/widget/pull/34", "🔀 acme/widget#34"),
            (
                "https://github.com/acme/widget/blob/\(revision)/App.swift#L2-L4",
                "📄 acme/widget · b4b5edb2/App.swift:2–4"
            ),
            ("https://github.com/acme/widget/releases/tag/v1.6.0", "🏷️ acme/widget@v1.6.0"),
            ("https://github.com/acme/widget/commit/\(revision)", "🔖 acme/widget@b4b5edb2"),
            ("https://github.com/acme/widget/actions/workflows/ci.yml", "⚙️ acme/widget · ci.yml"),
            ("https://github.com/acme/widget/actions/runs/123", "▶️ acme/widget · run 123"),
            ("https://github.com/acme/widget/actions/runs/123/job/456", "🛠️ acme/widget · job 456"),
            ("https://gitlab.com/team/sub/widget/-/merge_requests/4", "🔀 team/sub/widget!4"),
            ("https://gitlab.com/team/widget/-/issues/2", "📋 team/widget#2"),
            ("https://gitlab.com/team/widget/-/blob/main/App.swift#L2-4", "📄 team/widget · main/App.swift:2–4"),
            ("https://gitlab.com/team/widget/-/commit/\(revision)", "🔖 team/widget@b4b5edb2"),
            ("https://jira.example/browse/ACME-1", "🎫 ACME-1"),
            ("https://github.com/browse/ACME-1", "📦 browse/ACME-1"),
        ] {
            XCTAssertEqual(parser.parse(url)?.label, label, url)
            XCTAssertEqual(parser.parse(url)?.original, url)
        }
        XCTAssertNil(parser.parse("https://unknown.example/browse/ACME-1"))
    }

    func testEnterpriseRoutesQueryFragmentsAndRetryLinks() throws {
        var settings = Settings()
        settings.rules = [.init(service: .github, host: "github.example", port: 8443, basePath: "/code")]
        let parser = try Parser(settings: settings)
        for (path, label) in [
            ("actions/workflows/CI%20build.yaml?query=branch%3Amain#history", "⚙️ team/repo · CI build.yaml"),
            ("actions/workflows/1234", "⚙️ team/repo · 1234"),
            ("actions/runs/123/attempts/2?check_suite_focus=true#jobs", "▶️ team/repo · run 123 (attempt 2)"),
            ("actions/runs/123/job/456?pr=34#step:2:1", "🛠️ team/repo · job 456"),
            ("commit/\(revision)?diff=split#diff-123", "🔖 team/repo@b4b5edb2"),
            ("commit/abcdef1", "🔖 team/repo@abcdef1"),
        ] {
            let url = "https://github.example:8443/code/team/repo/" + path
            XCTAssertEqual(parser.parse(url)?.label, label)
            XCTAssertEqual(parser.parse(url)?.original, url)
            XCTAssertNil(parser.parse(url.replacingOccurrences(of: "/code/", with: "/codex/")))
            XCTAssertNil(parser.parse(url.replacingOccurrences(of: ":8443", with: "")))
        }
    }

    func testInvalidActionsAndCommitRoutesAreNotGuessed() throws {
        let parser = try Parser(settings: Settings())
        for path in [
            "actions", "actions/runs", "actions/runs/0", "actions/runs/-2", "actions/runs/١",
            "actions/runs/1/job/0", "actions/runs/1/job/2/extra", "actions/runs/1/attempts/0",
            "actions/workflows", "actions/workflows/ci.txt", "actions/workflows/a/ci.yml",
            "commit/abcdef", "commit/gggggggg", "commit/" + String(repeating: "a", count: 65),
            "commit/\(revision)/extra", "actions/runs/1?q=%0A",
        ] { XCTAssertNil(parser.parse("https://github.com/acme/widget/" + path), path) }
        XCTAssertNil(parser.parse("https://github.com.evil/acme/widget/actions/runs/1"))
        XCTAssertNil(parser.parse("http://github.com/acme/widget/actions/runs/1"))
    }

    func testIconPreferenceMigratesAndRoundTripsWithoutChangingConsentOrRules() throws {
        var settings = Settings()
        settings.consent = true
        settings.automatic = true
        settings.rules.append(.init(service: .github, host: "github.example"))
        settings.linkRules = [LinkRule.templates[0]]
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        old.removeValue(forKey: "showLinkIcons")
        let migrated = try Settings.decode(JSONSerialization.data(withJSONObject: old))
        XCTAssertTrue(migrated.showLinkIcons)
        XCTAssertEqual(migrated, settings)
        settings.showLinkIcons = false
        let decoded = try Settings.decode(JSONEncoder().encode(settings))
        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(
            try Parser(settings: decoded).parse("https://github.com/acme/widget/pull/34")?.label, "acme/widget#34")
        old["showLinkIcons"] = "yes"
        XCTAssertThrowsError(try Settings.decode(JSONSerialization.data(withJSONObject: old)))
    }

    func testCustomTextPriorityAndAuthoredEmojiSurvivePresentation() throws {
        var settings = Settings()
        var custom = LinkRule(
            name: "Review", urlPattern: "https://github.com/{owner}/{repo}/pull/{id}", labelTemplate: "Review {id}",
            overridesBuiltIns: true)
        settings.linkRules = [custom]
        let url = "https://github.com/acme/widget/pull/34"
        XCTAssertEqual(try Parser(settings: settings).parse(url)?.label, "🔀 Review 34")
        custom.labelTemplate = "✅ Review {id}"
        settings.linkRules = [custom]
        XCTAssertEqual(try Parser(settings: settings).parse(url)?.label, "✅ Review 34")
        settings.showLinkIcons = false
        XCTAssertEqual(try Parser(settings: settings).parse(url)?.label, "✅ Review 34")
        settings.showLinkIcons = true
        settings.linkRules = [
            .init(name: "Docs", urlPattern: "https://docs.example/browse/{part}", labelTemplate: "{part}")
        ]
        XCTAssertEqual(try Parser(settings: settings).parse("https://docs.example/browse/overview")?.label, "overview")
    }

    func testOlderCustomFileStylesAlsoShortenOnlyTheKnownRevision() throws {
        var settings = Settings()
        let pattern = LinkRule(
            name: "My file style", urlPattern: "https://github.com/{owner}/{repo}/blob/{path...}",
            labelTemplate: "{owner}/{repo} · {path}", overridesBuiltIns: true)
        settings.linkRules = [pattern]
        let url = "https://github.com/mamachanko/pink/blob/\(revision)/.github/workflows/ci.yml#L10"
        let parser = try Parser(settings: settings)
        XCTAssertEqual(parser.parse(url)?.label, "📄 mamachanko/pink · b4b5edb2/.github/workflows/ci.yml")
        XCTAssertEqual(parser.parse(url)?.original, url)
        XCTAssertEqual(parser.matches(url).first?.captures["path"], revision + "/.github/workflows/ci.yml")
        XCTAssertEqual(settings.linkRules, [pattern])
        settings.showLinkIcons = false
        XCTAssertEqual(
            try Parser(settings: settings).parse(url)?.label, "mamachanko/pink · b4b5edb2/.github/workflows/ci.yml")
        settings.linkRules = [
            .init(
                name: "Commit", urlPattern: "https://github.com/{owner}/{repo}/commit/{sha}",
                labelTemplate: "Commit {sha}", overridesBuiltIns: true)
        ]
        XCTAssertEqual(
            try Parser(settings: settings).parse("https://github.com/acme/widget/commit/" + revision)?.label,
            "Commit b4b5edb2")
        settings.linkRules = [.init(name: "Docs", urlPattern: "https://docs.example/{id}", labelTemplate: "{id}")]
        XCTAssertEqual(try Parser(settings: settings).parse("https://docs.example/" + revision)?.label, revision)
    }

    func testEmojiProseKeepsEveryOriginalSpanAndTarget() throws {
        let first = "https://github.com/acme/widget/pull/34"
        let second = "https://github.com/acme/widget/actions/runs/123/job/456#step:2:1"
        let original = "👩🏽 Review\n" + first + "\n" + second
        let result = try XCTUnwrap(Parser(settings: Settings()).parseText(original))
        XCTAssertEqual(result.original, original)
        XCTAssertEqual(result.displayText, "👩🏽 Review\n🔀 acme/widget#34\n🛠️ acme/widget · job 456")
        XCTAssertEqual(
            result.parts.compactMap { part -> String? in
                if case .reference(let reference) = part { return reference.original }
                return nil
            }, [first, second])
    }

    func testBuilderPreviewUsesTheSavedPresentationSetting() throws {
        var settings = Settings()
        var draft = LinkBuilderDraft(example: "https://jira.example/browse/ACME-1", settings: settings)
        XCTAssertEqual(draft.preview(in: settings)?.label, "🎫 ACME-1")
        XCTAssertEqual(draft.candidate?.labelTemplate, "{issue}")
        settings.showLinkIcons = false
        XCTAssertEqual(draft.preview(in: settings)?.label, "ACME-1")
        draft.updateExample("https://github.com/acme/widget/actions/runs/123", settings: settings)
        XCTAssertTrue(draft.alreadyWorks(in: settings))
        XCTAssertEqual(draft.preview(in: settings)?.label, "acme/widget · run 123")
    }
}
