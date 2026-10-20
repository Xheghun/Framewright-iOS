/// Metrics computed from retained events in insertion order, not sorted wall-clock order.
public struct SessionSummary: Equatable, Sendable {
    public let sessionId: String
    public let truncated: Bool
    public let timeToFirstFrameMs: Int64?
    public let rebufferCount: Int
    public let totalRebufferDurationMs: Int64
    public let rebufferRatio: Double?
    public let startupFailed: Bool
    public let trackSwitchesPerMinute: Double?
    public let averageDecoderInitializationMs: Double?
    public let droppedFrameCount: Int64
}

public struct SessionSummaryCalculator: Sendable {
    public init() {}

    /// Throws rather than overflowing when imported telemetry exceeds Int64 totals.
    public func calculate(_ snapshot: SessionSnapshot) throws -> SessionSummary {
        var firstFrame: Int64?
        var rebufferCount = 0
        var rebufferDuration: Int64 = 0
        var duration: Int64?
        var switches = 0
        var decoderCount = 0
        var decoderMean = 0.0
        var droppedFrames: Int64 = 0
        var startupFailed = false
        for event in snapshot.events {
            switch event.payload {
            case .renderFirstFrame(let value):
                if firstFrame == nil { firstFrame = value.elapsedSincePrepareMs }
            case .sessionEnd(let value):
                duration = value.durationMs > 0 ? value.durationMs : nil
            case .rebufferEnd(let value) where firstFrame != nil:
                rebufferCount += 1
                rebufferDuration = try adding(rebufferDuration, value.durationMs)
            case .trackSwitch:
                switches += 1
            case .decoderInit(let value):
                decoderCount += 1
                decoderMean += (Double(value.initializationDurationMs) - decoderMean) / Double(decoderCount)
            case .droppedFrames(let value):
                droppedFrames = try adding(droppedFrames, Int64(value.count))
            case .playbackError(let value) where firstFrame == nil:
                startupFailed = startupFailed || value.isFatal
            default: break
            }
        }
        return SessionSummary(
            sessionId: snapshot.sessionId, truncated: snapshot.truncated,
            timeToFirstFrameMs: firstFrame, rebufferCount: rebufferCount,
            totalRebufferDurationMs: rebufferDuration,
            rebufferRatio: duration.map { Double(rebufferDuration) / Double($0) },
            startupFailed: startupFailed,
            trackSwitchesPerMinute: duration.map { Double(switches) * 60_000 / Double($0) },
            averageDecoderInitializationMs: decoderCount > 0 ? decoderMean : nil,
            droppedFrameCount: droppedFrames
        )
    }

    private func adding(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let result = lhs.addingReportingOverflow(rhs)
        guard !result.overflow else { throw AnalyticsValidationError.invalidField("summary overflow") }
        return result.partialValue
    }
}
