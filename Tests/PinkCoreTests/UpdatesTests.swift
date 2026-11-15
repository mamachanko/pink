import Foundation
import XCTest

@testable import PinkCore

private actor ControlledReleaseChecker: ReleaseChecking {
    private var pending: CheckedContinuation<ReleaseOffer, any Error>?
    private var started: CheckedContinuation<Void, Never>?
    private(set) var calls = 0
    func latestRelease() async throws -> ReleaseOffer {
        calls += 1
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            started?.resume()
            started = nil
        }
    }
    func waitForRequest() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func resolve(_ result: Result<ReleaseOffer, any Error>) {
        pending?.resume(with: result)
        pending = nil
    }
}

final class UpdatesTests: XCTestCase {
    func testStableVersionsCompareNumericallyWithoutIntegerOverflow() throws {
        for value in ["", "1.2", "v1.2.3", "1.2.3-beta.1", "1.2.3+build", "01.2.3", "1.２.3", " 1.2.3"] {
            XCTAssertNil(ReleaseVersion(value))
        }
        XCTAssertLessThan(try XCTUnwrap(ReleaseVersion("1.9.9")), try XCTUnwrap(ReleaseVersion("1.10.0")))
        XCTAssertLessThan(
            try XCTUnwrap(ReleaseVersion("2.0.0")), try XCTUnwrap(ReleaseVersion("99999999999999999999999999.0.0")))
        XCTAssertEqual(ReleaseVersion("1.2.3"), ReleaseVersion("1.2.3"))
    }
    func testReleaseMetadataIsBoundedStableAndCannotSupplyAnExternalDestination() throws {
        let offer = try release("1.2.3", extra: ",\"html_url\":\"https://evil.example/download\"")
        XCTAssertEqual(offer.page.absoluteString, "https://github.com/mamachanko/pink/releases/tag/v1.2.3")
        for data in [
            Data(#"{"tag_name":"v1.2.3","draft":true,"prerelease":false}"#.utf8),
            Data(#"{"tag_name":"v1.2.3","draft":false,"prerelease":true}"#.utf8),
            Data(#"{"tag_name":"../../app","draft":false,"prerelease":false}"#.utf8),
            Data("{}".utf8), Data(repeating: 32, count: 262_145),
        ] { XCTAssertThrowsError(try ReleaseOffer(data: data)) }
    }
    @MainActor func testChecksAreUserInitiatedDeduplicatedAndCanBeRetried() async throws {
        let checker = ControlledReleaseChecker()
        let session = UpdateCheckSession(current: try XCTUnwrap(ReleaseVersion("1.2.3")), checker: checker)
        XCTAssertEqual(session.state, .idle)
        let operation = try XCTUnwrap(session.check())
        session.check()
        await checker.waitForRequest()
        let calls = await checker.calls
        XCTAssertEqual(calls, 1)
        let newer = try release("1.3.0")
        await checker.resolve(.success(newer))
        await operation.value
        XCTAssertEqual(session.state, .available(newer))
        let retry = try XCTUnwrap(session.check())
        await checker.waitForRequest()
        await checker.resolve(.failure(UpdateError.network))
        await retry.value
        XCTAssertEqual(session.state, .failed)
    }
    @MainActor func testNoDowngradeAndCancelledResultsCannotReplaceTheState() async throws {
        for version in ["1.2.3", "1.1.0"] {
            let checker = ControlledReleaseChecker()
            let session = UpdateCheckSession(current: try XCTUnwrap(ReleaseVersion("1.2.3")), checker: checker)
            let operation = try XCTUnwrap(session.check())
            await checker.waitForRequest()
            await checker.resolve(.success(try release(version)))
            await operation.value
            XCTAssertEqual(session.state, .current)
        }
        let checker = ControlledReleaseChecker()
        let session = UpdateCheckSession(current: try XCTUnwrap(ReleaseVersion("1.2.3")), checker: checker)
        let cancelled = try XCTUnwrap(session.check())
        await checker.waitForRequest()
        session.cancel()
        await checker.resolve(.success(try release("2.0.0")))
        await cancelled.value
        XCTAssertEqual(session.state, .idle)
    }
    private func release(_ version: String, extra: String = "") throws -> ReleaseOffer {
        try ReleaseOffer(data: Data("{\"tag_name\":\"v\(version)\",\"draft\":false,\"prerelease\":false\(extra)}".utf8))
    }
}
