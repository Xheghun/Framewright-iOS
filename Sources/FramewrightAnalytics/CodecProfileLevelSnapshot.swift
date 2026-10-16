import Foundation

public struct CodecProfileLevelSnapshot: Codable, Equatable, Sendable {
    public let profile: Int
    public let level: Int

    public init(profile: Int, level: Int) throws {
        self.profile = profile
        self.level = level
    }

    private enum CodingKeys: String, CodingKey {
        case profile
        case level
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            profile: try values.decode(Int.self, forKey: .profile),
            level: try values.decode(Int.self, forKey: .level)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(profile, forKey: .profile)
        try values.encode(level, forKey: .level)
    }
}
