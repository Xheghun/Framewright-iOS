import Foundation

public struct SessionStartPayload: Codable, Equatable, Sendable {
    public let mediaUri: String
    public let drmScheme: DRMScheme?
    public let deviceName: String?
    public let deviceModel: String
    public let osVersion: String
    public let appVersion: String

    public init(
        mediaUri: String, drmScheme: DRMScheme? = nil, deviceModel: String = "unknown", osVersion: String = "unknown",
        appVersion: String = "unknown", deviceName: String? = nil
    ) throws {
        self.mediaUri = mediaUri
        self.drmScheme = drmScheme
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
    }

    private enum CodingKeys: String, CodingKey {
        case mediaUri
        case drmScheme
        case deviceName
        case deviceModel
        case osVersion
        case appVersion
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            mediaUri: try values.decode(String.self, forKey: .mediaUri),
            drmScheme: try values.decodeIfPresent(DRMScheme.self, forKey: .drmScheme),
            deviceModel: try values.decode(String.self, forKey: .deviceModel),
            osVersion: try values.decode(String.self, forKey: .osVersion),
            appVersion: try values.decode(String.self, forKey: .appVersion),
            deviceName: try values.decodeIfPresent(String.self, forKey: .deviceName)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(mediaUri, forKey: .mediaUri)
        try values.encode(drmScheme, forKey: .drmScheme)
        try values.encodeIfPresent(deviceName, forKey: .deviceName)
        try values.encode(deviceModel, forKey: .deviceModel)
        try values.encode(osVersion, forKey: .osVersion)
        try values.encode(appVersion, forKey: .appVersion)
    }
}
