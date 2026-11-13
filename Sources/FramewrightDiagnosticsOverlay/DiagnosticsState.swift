import Foundation
import FramewrightAnalytics

public struct DiagnosticsState: Equatable, Sendable {
    public let snapshot: SessionSnapshot
    public let summary: SessionSummary
    public let status: String
    public let deviceName: String
    public let deviceModel: String
    public let droppedFrames: Int64?
    public let firstFrameSource: FirstFrameSource?
    public let selectedFormat: FormatSnapshot?
    public let decoder: DecoderInitPayload?
    public let bandwidth: BandwidthSamplePayload?
    public let bufferedMsAtStall: Int64?
    public let drmScheme: DRMScheme?
    public let drmSession: DRMSessionEventPayload?
    public let drmRequest: DRMRequestPayload?
    public let drmKey: DRMKeyStatusPayload?
    public let drmExpiryMs: Int64?
    public let lastIssue: String?

    /// Captures only the selected session; stale displayed state cannot be exported after a switch.
    public func exportJSON(sessionID: String, incomplete: Bool = false) throws -> String {
        guard snapshot.sessionId == sessionID else { throw AnalyticsValidationError.invalidField("sessionId") }
        return try DiagnosticEventJSONCodec().encodeSession(snapshot.mergingDeliveryIncomplete(incomplete))
    }

    public init(snapshot: SessionSnapshot) throws {
        self.snapshot = snapshot
        summary = try SessionSummaryCalculator().calculate(snapshot)
        var status = "Waiting for events"
        var name = "Unavailable"
        var model = "Unavailable"
        var hasDroppedFrames = false
        var firstFrameSource: FirstFrameSource?
        var selectedFormat: FormatSnapshot?
        var decoder: DecoderInitPayload?
        var bandwidth: BandwidthSamplePayload?
        var bufferedMs: Int64?
        var drmScheme: DRMScheme?
        var drmSession: DRMSessionEventPayload?
        var drmRequest: DRMRequestPayload?
        var drmKey: DRMKeyStatusPayload?
        var drmExpiryMs: Int64?
        var lastIssue: String?
        for event in snapshot.events {
            switch event.payload {
            case .sessionStart(let payload):
                name = payload.deviceName ?? payload.deviceModel
                model = payload.deviceModel
                status = "Started"
                drmScheme = payload.drmScheme
            case .playbackStateChanged(let payload):
                status = payload.status.rawValue.capitalized
            case .sessionEnd(let payload): status = payload.reason == .error ? "Failed" : "Ended"
            case .playbackError(let payload):
                if payload.isFatal { status = "Failed" }
                lastIssue = payload.errorCode
            case .loadError(let payload): lastIssue = payload.errorClass.rawValue
            case .trackSwitch(let payload): selectedFormat = payload.toFormat
            case .decoderInit(let payload) where payload.trackType == .video: decoder = payload
            case .bandwidthSample(let payload): bandwidth = payload
            case .rebufferStart(let payload): bufferedMs = payload.bufferedMsAtStart
            case .drmSessionEvent(let payload): drmSession = payload
            case .drmRequest(let payload): drmRequest = payload
            case .drmKeyStatus(let payload):
                drmKey = payload
                drmExpiryMs = payload.expirationTimeMs ?? drmExpiryMs
            case .drmExpirationUpdate(let payload): drmExpiryMs = payload.expirationTimeMs
            case .renderFirstFrame(let payload):
                if firstFrameSource == nil { firstFrameSource = payload.source }
            case .droppedFrames: hasDroppedFrames = true
            default: break
            }
        }
        self.firstFrameSource = firstFrameSource
        self.selectedFormat = selectedFormat
        self.decoder = decoder
        self.bandwidth = bandwidth
        bufferedMsAtStall = bufferedMs
        self.drmScheme = drmScheme
        self.drmSession = drmSession
        self.drmRequest = drmRequest
        self.drmKey = drmKey
        self.drmExpiryMs = drmExpiryMs
        self.lastIssue = lastIssue
        self.status = status
        deviceName = name
        deviceModel = model
        droppedFrames = hasDroppedFrames ? summary.droppedFrameCount : nil
    }
}
