import Foundation

/// Stable release versions only. Comparison does not depend on machine integer size.
public struct ReleaseVersion: Equatable, Comparable, Sendable {
    public let string: String
    private let components: [String]
    public init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, string.utf8.count <= 128,
            parts.allSatisfy({ part in
                !part.isEmpty && part.utf8.allSatisfy { (48...57).contains($0) }
                    && (part.count == 1 || part.first != "0")
            })
        else { return nil }
        self.string = string
        components = parts
    }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        for (left, right) in zip(lhs.components, rhs.components) where left != right {
            return left.count == right.count ? left < right : left.count < right.count
        }
        return false
    }
}

public struct ReleaseOffer: Equatable, Sendable {
    public let version: ReleaseVersion
    public var page: URL {
        URL(string: "https://github.com/mamachanko/pink/releases/tag/v\(version.string)")!
    }
    public init(data: Data) throws {
        struct Payload: Decodable {
            let tagName: String
            let draft: Bool
            let prerelease: Bool
            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case draft, prerelease
            }
        }
        guard data.count <= 262_144 else { throw UpdateError.invalidRelease }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard !payload.draft, !payload.prerelease, payload.tagName.hasPrefix("v"),
            let version = ReleaseVersion(String(payload.tagName.dropFirst()))
        else { throw UpdateError.invalidRelease }
        self.version = version
    }
}

public enum UpdateError: Error { case invalidRelease, network }

public protocol ReleaseChecking: Sendable {
    func latestRelease() async throws -> ReleaseOffer
}

public enum UpdateCheckState: Equatable, Sendable {
    case idle, checking, current
    case available(ReleaseOffer)
    case failed
}

/// One user-initiated request at a time; cancellation cannot publish stale results.
@MainActor public final class UpdateCheckSession {
    public private(set) var state = UpdateCheckState.idle
    public var onChange: (() -> Void)?
    private let current: ReleaseVersion
    private let checker: any ReleaseChecking
    private var task: Task<Void, Never>?
    private var generation = 0
    public init(current: ReleaseVersion, checker: any ReleaseChecking) {
        self.current = current
        self.checker = checker
    }
    @discardableResult public func check() -> Task<Void, Never>? {
        guard task == nil, state != .checking else { return task }
        generation += 1
        let token = generation
        state = .checking
        onChange?()
        task = Task { [weak self, checker] in
            do {
                let offer = try await checker.latestRelease()
                guard let self, !Task.isCancelled, token == self.generation else { return }
                self.finish(offer.version > self.current ? .available(offer) : .current)
            } catch {
                guard let self, !Task.isCancelled, token == self.generation else { return }
                self.finish(.failed)
            }
        }
        return task
    }
    public func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        state = .idle
        onChange?()
    }
    private func finish(_ next: UpdateCheckState) {
        task = nil
        state = next
        onChange?()
    }
}
