import Combine
import Foundation
import FramewrightAnalytics

@MainActor
public final class DiagnosticsModel: ObservableObject {
    @Published public private(set) var state: DiagnosticsState?
    @Published public private(set) var errorMessage: String?
    private var observationID: UUID?

    public init() {}

    /// Runs until its task is cancelled. Refreshes retained history without consuming live events.
    public func observe(pipeline: DiagnosticEventPipeline, sessionID: String) async {
        let id = UUID()
        observationID = id
        state = nil
        errorMessage = nil
        guard !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        while !Task.isCancelled, observationID == id {
            do {
                let snapshot = try await pipeline.snapshot(sessionId: sessionID)
                guard !Task.isCancelled, observationID == id else { return }
                if state?.snapshot != snapshot { state = try DiagnosticsState(snapshot: snapshot) }
                errorMessage = nil
                try await Task.sleep(for: .milliseconds(250))
            } catch is CancellationError { return } catch {
                guard observationID == id else { return }
                state = nil
                errorMessage = "Unable to read session diagnostics."
                return
            }
        }
    }
}
