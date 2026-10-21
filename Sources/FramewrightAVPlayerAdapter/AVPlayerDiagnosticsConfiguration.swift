import Foundation

public struct AVPlayerDiagnosticsConfiguration: Sendable {
    public var deviceModel: String
    public var osVersion: String
    public var appVersion: String
    public var includeErrorMessages: Bool
    public var sanitizeURI: @Sendable (String) -> String
    public var onDiagnosticsError: @MainActor @Sendable (any Error) -> Void

    public init(
        deviceModel: String = "unknown",
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        appVersion: String = "unknown",
        includeErrorMessages: Bool = false,
        sanitizeURI: @escaping @Sendable (String) -> String = AVPlayerDiagnosticsConfiguration.redactURI,
        onDiagnosticsError: @escaping @MainActor @Sendable (any Error) -> Void = { _ in }
    ) {
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.includeErrorMessages = includeErrorMessages
        self.sanitizeURI = sanitizeURI
        self.onDiagnosticsError = onDiagnosticsError
    }

    public static func redactURI(_ value: String) -> String {
        guard var parts = URLComponents(string: value),
            let scheme = parts.scheme?.lowercased(), ["https", "http"].contains(scheme),
            parts.host?.isEmpty == false
        else { return "<redacted>" }
        parts.user = nil
        parts.password = nil
        parts.query = nil
        parts.fragment = nil
        return parts.string ?? "<redacted>"
    }
}

public enum AVPlayerDiagnosticsError: Error, Equatable, Sendable {
    case alreadyAttached
    case notAttached
    case noCurrentItem
    case invalidSessionID
    case pipelineClosed
    case sinkFailures(Int)
}
