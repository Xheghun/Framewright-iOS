import Darwin
import Foundation

public struct AVPlayerDiagnosticsConfiguration: Sendable {
    private var deviceNameOverride: String?
    public var deviceName: String? {
        get { deviceNameOverride ?? DeviceNames.name(for: deviceModel) }
        set { deviceNameOverride = newValue }
    }
    public var deviceModel: String
    public var osVersion: String
    public var appVersion: String
    public var includeErrorMessages: Bool
    public var sanitizeURI: @Sendable (String) -> String
    public var onDiagnosticsError: @MainActor @Sendable (any Error) -> Void

    public init(
        deviceModel: String = AVPlayerDiagnosticsConfiguration.currentDeviceModel,
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        appVersion: String = AVPlayerDiagnosticsConfiguration.currentAppVersion,
        deviceName: String? = nil,
        includeErrorMessages: Bool = false,
        sanitizeURI: @escaping @Sendable (String) -> String = AVPlayerDiagnosticsConfiguration.redactURI,
        onDiagnosticsError: @escaping @MainActor @Sendable (any Error) -> Void = { _ in }
    ) {
        self.deviceNameOverride = deviceName
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.includeErrorMessages = includeErrorMessages
        self.sanitizeURI = sanitizeURI
        self.onDiagnosticsError = onDiagnosticsError
    }

    public static var currentDeviceModel: String {
        #if targetEnvironment(simulator)
            if let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !model.isEmpty {
                return model
            }
        #endif
        var system = utsname()
        guard uname(&system) == 0 else { return "unknown" }
        return withUnsafeBytes(of: &system.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    public static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "unknown"
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
    case eventQueueOverflow(capacity: Int)
    case deliveryPending
    case pipelineClosed
    case sinkFailures(Int)
}
