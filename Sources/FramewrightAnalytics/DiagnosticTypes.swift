import Foundation

public let diagnosticSchemaVersion = 3

public enum AnalyticsValidationError: Error, Equatable, Sendable {
    case invalidField(String)
}

public enum EventType: String, Codable, Sendable, CaseIterable {
    case playbackStateChanged = "PLAYBACK_STATE_CHANGED"
    case positionDiscontinuity = "POSITION_DISCONTINUITY"
    case sessionStart = "SESSION_START"
    case sessionEnd = "SESSION_END"
    case renderFirstFrame = "RENDER_FIRST_FRAME"
    case rebufferStart = "REBUFFER_START"
    case rebufferEnd = "REBUFFER_END"
    case trackSwitch = "TRACK_SWITCH"
    case decoderInit = "DECODER_INIT"
    case droppedFrames = "DROPPED_FRAMES"
    case loadError = "LOAD_ERROR"
    case drmKeyStatus = "DRM_KEY_STATUS"
    case drmSessionEvent = "DRM_SESSION_EVENT"
    case drmRequest = "DRM_REQUEST"
    case drmExpirationUpdate = "DRM_EXPIRATION_UPDATE"
    case bandwidthSample = "BANDWIDTH_SAMPLE"
    case playbackError = "PLAYBACK_ERROR"
}

public enum PlayerState: String, Codable, Sendable, CaseIterable {
    case idle = "IDLE"
    case buffering = "BUFFERING"
    case ready = "READY"
    case ended = "ENDED"
}

public enum DRMScheme: String, Codable, Sendable, CaseIterable {
    case widevine = "WIDEVINE"
    case fairPlay = "FAIRPLAY"
    case playReady = "PLAYREADY"
    case other = "OTHER"
}

public enum TrackType: String, Codable, Sendable, CaseIterable {
    case video = "VIDEO"
    case audio = "AUDIO"
    case text = "TEXT"
}

public enum TrackSwitchReason: String, Codable, Sendable, CaseIterable {
    case bandwidthIncrease = "BANDWIDTH_INCREASE"
    case bandwidthDecrease = "BANDWIDTH_DECREASE"
    case bufferHealth = "BUFFER_HEALTH"
    case manualOverride = "MANUAL_OVERRIDE"
    case initial = "INITIAL"
    case unknown = "UNKNOWN"
}

public enum LoadErrorClass: String, Codable, Sendable, CaseIterable {
    case timeout = "TIMEOUT"
    case http4xx = "HTTP_4XX"
    case http5xx = "HTTP_5XX"
    case dns = "DNS"
    case connection = "CONNECTION"
    case unknown = "UNKNOWN"
}

public enum SessionEndReason: String, Codable, Sendable, CaseIterable {
    case userStopped = "USER_STOPPED"
    case appBackgrounded = "APP_BACKGROUNDED"
    case playbackEnded = "PLAYBACK_ENDED"
    case replaced = "REPLACED"
    case error = "ERROR"
    case released = "RELEASED"
}

public enum DRMKeyState: String, Codable, Sendable, CaseIterable {
    case usable = "USABLE"
    case expired = "EXPIRED"
    case outputRestricted = "OUTPUT_RESTRICTED"
    case statusPending = "STATUS_PENDING"
    case internalError = "INTERNAL_ERROR"
    case unknown = "UNKNOWN"
}

public enum DRMSessionEventType: String, Codable, Sendable, CaseIterable {
    case acquired = "ACQUIRED"
    case keysLoaded = "KEYS_LOADED"
    case keysRestored = "KEYS_RESTORED"
    case keysRemoved = "KEYS_REMOVED"
    case released = "RELEASED"
    case error = "ERROR"
}

public enum DRMSessionState: String, Codable, Sendable, CaseIterable {
    case released = "RELEASED"
    case error = "ERROR"
    case opening = "OPENING"
    case opened = "OPENED"
    case openedWithKeys = "OPENED_WITH_KEYS"
    case unknown = "UNKNOWN"
}

public enum DRMRequestKind: String, Codable, Sendable, CaseIterable {
    case license = "LICENSE"
    case provisioning = "PROVISIONING"
}

public enum DRMLicenseRequestType: String, Codable, Sendable, CaseIterable {
    case initial = "INITIAL"
    case renewal = "RENEWAL"
    case release = "RELEASE"
    case update = "UPDATE"
    case none = "NONE"
    case unknown = "UNKNOWN"
}

public enum CodecImplementationType: String, Codable, Sendable, CaseIterable {
    case hardwareAccelerated = "HARDWARE_ACCELERATED"
    case softwareOnly = "SOFTWARE_ONLY"
    case unknown = "UNKNOWN"
}

public enum CodecClassificationSource: String, Codable, Sendable, CaseIterable {
    case platform = "PLATFORM"
    case nameHeuristic = "NAME_HEURISTIC"
    case unknown = "UNKNOWN"
}

public enum CodecFormatSupport: String, Codable, Sendable, CaseIterable {
    case supported = "SUPPORTED"
    case unsupported = "UNSUPPORTED"
    case unknown = "UNKNOWN"
}
