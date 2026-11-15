import Foundation
import PinkCore

/// No cookies, credentials, disk cache, clipboard data or background requests.
public struct GitHubReleaseChecker: ReleaseChecking {
    public init() {}
    public func latestRelease() async throws -> ReleaseOffer {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/mamachanko/pink/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Pink-Update-Check", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
            response.url?.scheme == "https", response.url?.host == "api.github.com"
        else { throw UpdateError.network }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 262_144 else { throw UpdateError.invalidRelease }
            data.append(byte)
        }
        return try ReleaseOffer(data: data)
    }
}
