import Foundation
import FramewrightAnalytics

struct DiagnosticTime: Sendable {
    let wallMs: Int64
    let monotonicMs: Int64

    static var now: Self {
        Self(
            wallMs: milliseconds(Date().timeIntervalSince1970),
            monotonicMs: milliseconds(ProcessInfo.processInfo.systemUptime))
    }

    static func milliseconds(_ seconds: Double) -> Int64 {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        let value = seconds * 1_000
        guard value < Double(Int64.max) else { return Int64.max }
        return Int64(value)
    }
}

enum PlaybackControl: Sendable { case paused, waiting, playing }

struct PlaybackSessionState: Sendable {
    private struct Session: Sendable {
        let id: String
        let startedMs: Int64
        var preparedMs: Int64?
        var firstFrame = false
        var firstFrameSource: FirstFrameSource = .rendered
        var hasPlayed = false
        var rebufferMs: Int64?
        var seeking = false
        var control: PlaybackControl = .paused
    }

    private var session: Session?
    private(set) var playerState: PlayerState = .idle
    var sessionID: String? { session?.id }

    mutating func start(id: String, payload: SessionStartPayload, preparedMs: Int64?, at time: DiagnosticTime) throws
        -> [DiagnosticEvent]
    {
        var events = try end(reason: .replaced, at: time)
        session = Session(id: id, startedMs: time.monotonicMs, preparedMs: preparedMs)
        playerState = .idle
        events.append(try event(.sessionStart(payload), at: time))
        return events
    }

    mutating func markPreparation(at time: DiagnosticTime) {
        guard session?.firstFrame == false else { return }
        session?.preparedMs = time.monotonicMs
    }

    mutating func firstFrame(at time: DiagnosticTime, source: FirstFrameSource = .rendered) throws -> [DiagnosticEvent]
    {
        guard let current = session, !current.firstFrame, let prepared = current.preparedMs else { return [] }
        session?.firstFrame = true
        session?.firstFrameSource = source
        return [
            try event(
                .renderFirstFrame(
                    RenderFirstFramePayload(
                        elapsedSincePrepareMs: max(0, time.monotonicMs - prepared), source: source)), at: time)
        ]
    }

    mutating func update(
        control: PlaybackControl, ready: Bool, buffering: Bool,
        bufferedMs: Int64, at time: DiagnosticTime
    ) throws -> [DiagnosticEvent] {
        guard session != nil else { return [] }
        let changed = session?.control != control
        session?.control = control
        let status: PlaybackStatus
        switch control {
        case .paused:
            status = .paused
            playerState = ready ? .ready : .idle
        case .waiting:
            status = .waiting
            playerState = .buffering
        case .playing:
            session?.hasPlayed = true
            status = .playing
            playerState = .ready
        }
        let transition = changed ? [try event(.playbackStateChanged(.init(status: status)), at: time)] : []
        switch control {
        case .paused:
            // Paused time is not a completed playback rebuffer.
            session?.rebufferMs = nil
            return transition
        case .playing:
            return try finishRebuffer(at: time) + transition
        case .waiting:
            guard buffering, session?.firstFrame == true,
                session?.firstFrameSource != .readyForDisplay || session?.hasPlayed == true,
                session?.seeking == false,
                session?.rebufferMs == nil
            else { return transition }
            session?.rebufferMs = time.monotonicMs
            return try [event(.rebufferStart(RebufferStartPayload(bufferedMsAtStart: bufferedMs)), at: time)]
                + transition
        }
    }

    mutating func positionJumped(to positionMs: Int64, at time: DiagnosticTime) throws -> [DiagnosticEvent] {
        guard session != nil else { return [] }
        session?.rebufferMs = nil
        return [try event(.positionDiscontinuity(PositionDiscontinuityPayload(positionMs: positionMs)), at: time)]
    }

    mutating func droppedFrames(count: Int, elapsedMs: Int64, at time: DiagnosticTime) throws -> [DiagnosticEvent] {
        guard session != nil else { return [] }
        return [try event(.droppedFrames(.init(count: count, elapsedMs: elapsedMs)), at: time)]
    }

    mutating func beginSeek() {
        session?.seeking = true
        session?.rebufferMs = nil
    }

    mutating func finishSeek() { session?.seeking = false }

    mutating func fail(code: String, message: String?, at time: DiagnosticTime) throws -> [DiagnosticEvent] {
        guard session != nil else { return [] }
        let error = try event(.playbackError(PlaybackErrorPayload(errorCode: code, errorMessage: message)), at: time)
        return try [error] + end(reason: .error, at: time)
    }

    mutating func end(reason: SessionEndReason, at time: DiagnosticTime) throws -> [DiagnosticEvent] {
        guard let current = session else { return [] }
        playerState = .ended
        var events = try finishRebuffer(at: time)
        events.append(
            try event(
                .sessionEnd(
                    SessionEndPayload(
                        durationMs: max(0, time.monotonicMs - current.startedMs), reason: reason)), at: time))
        session = nil
        return events
    }

    private mutating func finishRebuffer(at time: DiagnosticTime) throws -> [DiagnosticEvent] {
        guard let start = session?.rebufferMs else { return [] }
        session?.rebufferMs = nil
        return [try event(.rebufferEnd(RebufferEndPayload(durationMs: max(0, time.monotonicMs - start))), at: time)]
    }

    private func event(_ payload: DiagnosticPayload, at time: DiagnosticTime) throws -> DiagnosticEvent {
        guard let session else { throw AVPlayerDiagnosticsError.noCurrentItem }
        return try DiagnosticEvent(
            metadata: DiagnosticEventMetadata(
                sessionId: session.id, eventId: UUID().uuidString, timestampMs: time.wallMs,
                elapsedRealtimeMs: time.monotonicMs, playerState: playerState), payload: payload)
    }
}
