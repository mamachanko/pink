import Foundation

public struct Settings: Codable, Equatable, Sendable {
    public var schema = 1
    public var consent = false
    public var automatic = false
    public var rules = HostRule.defaults
    public init() {}
    public static func decode(_ data: Data) throws -> Settings {
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.schema == 1 else { throw ValidationError.invalidRules }
        _ = try Parser(rules: value.rules)
        return value
    }
}
