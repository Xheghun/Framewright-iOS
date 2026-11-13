import Foundation
import FramewrightAnalytics

/// Host-supplied diagnostics for a FairPlay integration. This type never handles license payloads.
@MainActor
public final class FramewrightDRMInspector {
    public struct Attempt: Hashable, Sendable {
        fileprivate let id: UUID
    }

    public enum Outcome: Sendable {
        case success
        case networkFailure
        case timeout
        case rejected
        case cancelled

        fileprivate var errorCode: String? {
            switch self {
            case .success: nil
            case .networkFailure: "network"
            case .timeout: "timeout"
            case .rejected: "rejected"
            case .cancelled: "cancelled"
            }
        }
    }

    private struct Request {
        let kind: DRMRequestKind
        let licenseType: DRMLicenseRequestType?
        let attempt: Int
        let start: ContinuousClock.Instant
    }

    private let sessionID: String
    private let pipeline: DiagnosticEventPipeline
    private var pending: [Attempt: Request] = [:]
    private var active = true

    public init(sessionID: String, pipeline: DiagnosticEventPipeline) throws {
        _ = try DiagnosticEventMetadata(
            sessionId: sessionID, eventId: "validation", timestampMs: 0, elapsedRealtimeMs: 0)
        self.sessionID = sessionID
        self.pipeline = pipeline
    }

    public func beginAttempt(
        kind: DRMRequestKind, licenseType: DRMLicenseRequestType? = nil, number: Int
    ) throws -> Attempt? {
        guard active else { return nil }
        guard pending.count < 128 else { throw AnalyticsValidationError.invalidField("pendingDRMAttempts") }
        _ = try DRMRequestPayload(
            requestKind: kind, licenseRequestType: licenseType, attemptNumber: number,
            durationMs: 0, successful: false)
        let token = Attempt(id: UUID())
        pending[token] = Request(kind: kind, licenseType: licenseType, attempt: number, start: .now)
        return token
    }

    @discardableResult
    public func finishAttempt(_ token: Attempt, outcome: Outcome) async throws -> PublishResult? {
        guard active, let request = pending.removeValue(forKey: token) else { return nil }
        let duration = request.start.duration(to: .now).components
        let seconds = min(duration.seconds, Int64.max / 1_000 - 1)
        let milliseconds = seconds * 1_000 + duration.attoseconds / 1_000_000_000_000_000
        let payload = try DRMRequestPayload(
            requestKind: request.kind, licenseRequestType: request.licenseType, attemptNumber: request.attempt,
            durationMs: max(0, milliseconds), successful: outcome.errorCode == nil, errorCode: outcome.errorCode)
        return try await publish(.drmRequest(payload))
    }

    @discardableResult
    public func recordSessionEvent(_ event: DRMSessionEventType, state: DRMSessionState? = nil) async throws
        -> PublishResult?
    {
        guard active else { return nil }
        return try await publish(.drmSessionEvent(DRMSessionEventPayload(eventType: event, state: state)))
    }

    public func detach() {
        active = false
        pending.removeAll()
    }

    private func publish(_ payload: DiagnosticPayload) async throws -> PublishResult {
        let metadata = try DiagnosticEventMetadata(
            sessionId: sessionID, eventId: UUID().uuidString,
            timestampMs: Int64(Date().timeIntervalSince1970 * 1_000),
            elapsedRealtimeMs: Int64(ProcessInfo.processInfo.systemUptime * 1_000))
        return await pipeline.publish(DiagnosticEvent(metadata: metadata, payload: payload))
    }
}
