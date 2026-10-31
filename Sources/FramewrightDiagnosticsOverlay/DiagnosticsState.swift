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

    public init(snapshot: SessionSnapshot) throws {
        self.snapshot = snapshot
        summary = try SessionSummaryCalculator().calculate(snapshot)
        var status = "Waiting for events"
        var name = "Unavailable"
        var model = "Unavailable"
        var hasDroppedFrames = false
        var firstFrameSource: FirstFrameSource?
        for event in snapshot.events {
            switch event.payload {
            case .sessionStart(let payload):
                name = payload.deviceName ?? payload.deviceModel
                model = payload.deviceModel
                status = "Started"
            case .playbackStateChanged(let payload):
                status = payload.status.rawValue.capitalized
            case .sessionEnd(let payload): status = payload.reason == .error ? "Failed" : "Ended"
            case .playbackError(let payload) where payload.isFatal: status = "Failed"
            case .renderFirstFrame(let payload):
                if firstFrameSource == nil { firstFrameSource = payload.source }
            case .droppedFrames: hasDroppedFrames = true
            default: break
            }
        }
        self.firstFrameSource = firstFrameSource
        self.status = status
        deviceName = name
        deviceModel = model
        droppedFrames = hasDroppedFrames ? summary.droppedFrameCount : nil
    }
}
