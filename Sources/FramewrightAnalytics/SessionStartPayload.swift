import Foundation

/// Immutable, validated diagnostic data. Durations and timestamps use milliseconds.
public struct SessionStartPayload: Codable, Equatable, Sendable {
    public let mediaUri: String
    public let drmScheme: DRMScheme?
    public let deviceModel: String
    public let osVersion: String
    public let appVersion: String

    public init(
        mediaUri: String, drmScheme: DRMScheme? = nil, deviceModel: String = "unknown", osVersion: String = "unknown",
        appVersion: String = "unknown"
    ) throws {
        self.mediaUri = mediaUri
        self.drmScheme = drmScheme
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
    }

    private enum CodingKeys: String, CodingKey {
        case mediaUri
        case drmScheme
        case deviceModel
        case osVersion
        case appVersion
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            mediaUri: try values.decode(String.self, forKey: .mediaUri),
            drmScheme: try values.decodeIfPresent(DRMScheme.self, forKey: .drmScheme),
            deviceModel: try values.decodeIfPresent(String.self, forKey: .deviceModel) ?? "unknown",
            osVersion: try values.decodeIfPresent(String.self, forKey: .osVersion) ?? "unknown",
            appVersion: try values.decodeIfPresent(String.self, forKey: .appVersion) ?? "unknown"
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(mediaUri, forKey: .mediaUri)
        try values.encode(drmScheme, forKey: .drmScheme)
        try values.encode(deviceModel, forKey: .deviceModel)
        try values.encode(osVersion, forKey: .osVersion)
        try values.encode(appVersion, forKey: .appVersion)
    }
}
