import Foundation

public struct Settings: Codable, Equatable, Sendable {
    public var schema = 1
    public var consent = false
    public var automatic = false
    public var rewriteFormattedURLs = false
    public var showLinkIcons = true
    public var rules = HostRule.defaults
    public var linkRules: [LinkRule] = []
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case schema, consent, automatic, rules, linkRules, rewriteFormattedURLs, showLinkIcons
    }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schema = try values.decode(Int.self, forKey: .schema)
        consent = try values.decode(Bool.self, forKey: .consent)
        automatic = try values.decode(Bool.self, forKey: .automatic)
        rewriteFormattedURLs =
            values.contains(.rewriteFormattedURLs)
            ? try values.decode(Bool.self, forKey: .rewriteFormattedURLs) : false
        showLinkIcons = values.contains(.showLinkIcons) ? try values.decode(Bool.self, forKey: .showLinkIcons) : true
        rules = try values.decode([HostRule].self, forKey: .rules)
        // Version-1 preferences from existing installs retain consent and host configuration.
        linkRules = values.contains(.linkRules) ? try values.decode([LinkRule].self, forKey: .linkRules) : []
    }
    public static func decode(_ data: Data) throws -> Settings {
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.schema == 1 else { throw ValidationError.invalidRules }
        _ = try Parser(settings: value)
        return value
    }
}
