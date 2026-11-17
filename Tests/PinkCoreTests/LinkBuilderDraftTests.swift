import XCTest

@testable import PinkCore

final class LinkBuilderDraftTests: XCTestCase {
    private let jira = "https://jira.example/browse/ACME-184273"

    func testSecondExampleKeepsChosenContextAndExactDestination() throws {
        let settings = Settings()
        var draft = LinkBuilderDraft(example: jira, settings: settings)
        draft.setContext(true, settings: settings)
        let rule = try XCTUnwrap(draft.candidate)
        let second = "https://jira.example/browse/OTHER-52?view=all#comment-2"
        draft.updateExample(second, settings: settings)
        XCTAssertEqual(draft.candidate, rule)
        XCTAssertEqual(draft.preview(in: settings)?.label, "Jira · OTHER-52")
        XCTAssertEqual(draft.preview(in: settings)?.original, second)
        XCTAssertTrue(draft.canFinish(in: settings))
    }

    func testSelectedPathPartStaysSelectedForAnotherMatchingLink() {
        let settings = Settings()
        var draft = LinkBuilderDraft(example: "https://docs.example/team/guide", settings: settings)
        draft.choosePart(0, settings: settings)
        draft.updateExample("https://docs.example/other/guide#section", settings: settings)
        XCTAssertEqual(draft.selection, 0)
        XCTAssertEqual(draft.preview(in: settings)?.label, "other")
        XCTAssertTrue(draft.canFinish(in: settings))
    }

    func testAdvancedEditsSurviveMatchingNonmatchingAndIncompleteExamples() throws {
        let settings = Settings()
        var draft = LinkBuilderDraft(example: jira, settings: settings)
        draft.edit(\.urlPattern, to: "https://jira.example/browse/{ticket}")
        draft.edit(\.labelTemplate, to: "Review {ticket}")
        let rule = try XCTUnwrap(draft.candidate)
        for example in ["", "https://", "https://jira.example/projects/OTHER-52"] {
            draft.updateExample(example, settings: settings)
            XCTAssertEqual(draft.candidate, rule)
            XCTAssertNil(draft.preview(in: settings))
            XCTAssertFalse(draft.canFinish(in: settings))
        }
        draft.updateExample("https://jira.example/browse/OTHER-52", settings: settings)
        XCTAssertEqual(draft.preview(in: settings)?.label, "Review OTHER-52")
        XCTAssertTrue(draft.usesCustomPattern)
        draft.useSuggestion(settings: settings)
        XCTAssertEqual(draft.preview(in: settings)?.label, "OTHER-52")
        XCTAssertFalse(draft.usesCustomPattern)
    }

    func testChoicesKeepExplicitMetadataAndDoNotLeakAnOldRuleIdentity() throws {
        let existing = LinkRule(
            name: "Saved Jira", urlPattern: "https://jira.example/browse/{issue}", labelTemplate: "{issue}")
        var settings = Settings()
        settings.linkRules = [existing]
        var draft = LinkBuilderDraft(example: jira, settings: settings)
        XCTAssertTrue(draft.alreadyWorks(in: settings))
        draft.customize()
        XCTAssertEqual(draft.candidate?.id, existing.id)
        draft.edit(\.name, to: "My short links")
        draft.edit(\.overridesBuiltIns, to: false)
        draft.setContext(true, settings: settings)
        draft.updateExample("https://docs.example/guides/intro", settings: settings)
        XCTAssertNotEqual(draft.candidate?.id, existing.id)
        XCTAssertEqual(draft.candidate?.name, "My short links")
        XCTAssertEqual(draft.candidate?.overridesBuiltIns, false)
        XCTAssertEqual(settings.linkRules, [existing])
    }

    func testActualWinnerIsPreviewedAndKnownLinksNeedNoSave() throws {
        let settings = Settings()
        var draft = LinkBuilderDraft(example: "https://github.com/acme/widget/pull/123", settings: settings)
        XCTAssertTrue(draft.alreadyWorks(in: settings))
        XCTAssertEqual(draft.preview(in: settings)?.label, "acme/widget#123")
        draft.customize()
        draft.setContext(false, settings: settings)
        XCTAssertFalse(draft.alreadyWorks(in: settings))
        XCTAssertEqual(draft.preview(in: settings)?.label, "123")
        draft.edit(\.overridesBuiltIns, to: false)
        XCTAssertEqual(draft.preview(in: settings)?.label, "acme/widget#123")
    }

    func testHTTPApprovalIsScopedToAnEndpointAndCannotBeBypassedByAdvancedEdits() {
        let settings = Settings()
        var draft = LinkBuilderDraft(example: "http://jira.example:8080/browse/ACME-1", settings: settings)
        XCTAssertFalse(draft.canFinish(in: settings))
        draft.approveHTTP(true)
        draft.updateExample("http://jira.example:8080/browse/OTHER-2", settings: settings)
        XCTAssertTrue(draft.canFinish(in: settings))
        draft.updateExample("http://jira.example:8081/browse/OTHER-2", settings: settings)
        XCTAssertFalse(draft.allowHTTP)
        draft.edit(\.urlPattern, to: "http://other.example/browse/{ticket}")
        draft.edit(\.labelTemplate, to: "{ticket}")
        draft.updateExample("http://other.example/browse/OTHER-2", settings: settings)
        XCTAssertFalse(draft.canFinish(in: settings))
        draft.approveHTTP(true)
        XCTAssertTrue(draft.canFinish(in: settings))
    }

    func testInvalidCustomPatternRetainsTheDraftAndBlocksSave() {
        let settings = Settings()
        var draft = LinkBuilderDraft(example: jira, settings: settings)
        draft.edit(\.labelTemplate, to: "{unknown}")
        XCTAssertNotNil(draft.validation(in: settings))
        XCTAssertNil(draft.preview(in: settings))
        XCTAssertFalse(draft.canFinish(in: settings))
        draft.updateExample("https://jira.example/browse/OTHER-2", settings: settings)
        XCTAssertEqual(draft.candidate?.labelTemplate, "{unknown}")
    }
}
