/// Adapter boundary. Implementations own observations, never the host player's lifetime.
@MainActor
public protocol PlayerEventSource: AnyObject {
    /// Reject repeated attachment and restore the detached state if setup fails.
    func attach(pipeline: DiagnosticEventPipeline, sessionId: String) throws
    /// Release observations. Repeated calls must be safe.
    func detach()
}

public protocol DecoderCapabilityResolver: Sendable {
    func resolve(_ request: DecoderInspectionRequest) throws -> DecoderCapabilitySnapshot?
}
