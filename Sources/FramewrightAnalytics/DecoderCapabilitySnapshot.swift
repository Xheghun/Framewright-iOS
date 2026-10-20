import Foundation

public struct DecoderCapabilitySnapshot: Codable, Equatable, Sendable {
    public let canonicalName: String?
    public let implementationType: CodecImplementationType
    public let classificationSource: CodecClassificationSource
    public let isVendor: Bool?
    public let isAlias: Bool?
    public let profileLevels: [CodecProfileLevelSnapshot]
    public let supportsAdaptivePlayback: Bool
    public let supportsSecurePlayback: Bool
    public let supportsTunneledPlayback: Bool
    public let maxSupportedInstances: Int?
    public let selectedFormatSupport: CodecFormatSupport
    public let videoCapabilities: VideoCodecCapabilitiesSnapshot?

    public init(
        canonicalName: String? = nil, implementationType: CodecImplementationType,
        classificationSource: CodecClassificationSource, isVendor: Bool? = nil, isAlias: Bool? = nil,
        profileLevels: [CodecProfileLevelSnapshot] = [], supportsAdaptivePlayback: Bool, supportsSecurePlayback: Bool,
        supportsTunneledPlayback: Bool, maxSupportedInstances: Int? = nil,
        selectedFormatSupport: CodecFormatSupport = .unknown, videoCapabilities: VideoCodecCapabilitiesSnapshot? = nil
    ) throws {
        guard maxSupportedInstances.map({ $0 > 0 }) ?? true else {
            throw AnalyticsValidationError.invalidField("maxSupportedInstances")
        }
        try validateSchemaInteger(maxSupportedInstances, field: "maxSupportedInstances")
        self.canonicalName = canonicalName
        self.implementationType = implementationType
        self.classificationSource = classificationSource
        self.isVendor = isVendor
        self.isAlias = isAlias
        self.profileLevels = profileLevels
        self.supportsAdaptivePlayback = supportsAdaptivePlayback
        self.supportsSecurePlayback = supportsSecurePlayback
        self.supportsTunneledPlayback = supportsTunneledPlayback
        self.maxSupportedInstances = maxSupportedInstances
        self.selectedFormatSupport = selectedFormatSupport
        self.videoCapabilities = videoCapabilities
    }

    private enum CodingKeys: String, CodingKey {
        case canonicalName
        case implementationType
        case classificationSource
        case isVendor
        case isAlias
        case profileLevels
        case supportsAdaptivePlayback
        case supportsSecurePlayback
        case supportsTunneledPlayback
        case maxSupportedInstances
        case selectedFormatSupport
        case videoCapabilities
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            canonicalName: try values.decodeIfPresent(String.self, forKey: .canonicalName),
            implementationType: try values.decode(CodecImplementationType.self, forKey: .implementationType),
            classificationSource: try values.decode(CodecClassificationSource.self, forKey: .classificationSource),
            isVendor: try values.decodeIfPresent(Bool.self, forKey: .isVendor),
            isAlias: try values.decodeIfPresent(Bool.self, forKey: .isAlias),
            profileLevels: try values.decode([CodecProfileLevelSnapshot].self, forKey: .profileLevels),
            supportsAdaptivePlayback: try values.decode(Bool.self, forKey: .supportsAdaptivePlayback),
            supportsSecurePlayback: try values.decode(Bool.self, forKey: .supportsSecurePlayback),
            supportsTunneledPlayback: try values.decode(Bool.self, forKey: .supportsTunneledPlayback),
            maxSupportedInstances: try values.decodeIfPresent(Int.self, forKey: .maxSupportedInstances),
            selectedFormatSupport: try values.decode(CodecFormatSupport.self, forKey: .selectedFormatSupport),
            videoCapabilities: try values.decodeIfPresent(
                VideoCodecCapabilitiesSnapshot.self, forKey: .videoCapabilities)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(canonicalName, forKey: .canonicalName)
        try values.encode(implementationType, forKey: .implementationType)
        try values.encode(classificationSource, forKey: .classificationSource)
        try values.encode(isVendor, forKey: .isVendor)
        try values.encode(isAlias, forKey: .isAlias)
        try values.encode(profileLevels, forKey: .profileLevels)
        try values.encode(supportsAdaptivePlayback, forKey: .supportsAdaptivePlayback)
        try values.encode(supportsSecurePlayback, forKey: .supportsSecurePlayback)
        try values.encode(supportsTunneledPlayback, forKey: .supportsTunneledPlayback)
        try values.encode(maxSupportedInstances, forKey: .maxSupportedInstances)
        try values.encode(selectedFormatSupport, forKey: .selectedFormatSupport)
        try values.encode(videoCapabilities, forKey: .videoCapabilities)
    }
}
