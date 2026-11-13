import FramewrightAnalytics
import FramewrightDRMInspector
import Testing

@Test @MainActor func hostAttemptsReportSanitizedOutcomesAndRejectStaleTokens() async throws {
    let pipeline = try DiagnosticEventPipeline()
    let inspector = try FramewrightDRMInspector(sessionID: "protected", pipeline: pipeline)
    try await inspector.recordSessionEvent(.acquired, state: .opening)
    let firstToken = try inspector.beginAttempt(kind: .license, licenseType: .initial, number: 1)
    let first = try #require(firstToken)
    let secondToken = try inspector.beginAttempt(kind: .license, licenseType: .initial, number: 2)
    let second = try #require(secondToken)
    try await inspector.finishAttempt(first, outcome: .cancelled)
    try await inspector.finishAttempt(second, outcome: .success)
    #expect(try await inspector.finishAttempt(second, outcome: .rejected) == nil)
    let staleToken = try inspector.beginAttempt(kind: .license, licenseType: .renewal, number: 1)
    let stale = try #require(staleToken)
    inspector.detach()
    #expect(try await inspector.finishAttempt(stale, outcome: .timeout) == nil)
    let snapshot = try await pipeline.snapshot(sessionId: "protected")
    #expect(snapshot.events.map(\.type) == [.drmSessionEvent, .drmRequest, .drmRequest])
    let attempts = snapshot.events.compactMap { event -> DRMRequestPayload? in
        guard case .drmRequest(let request) = event.payload else { return nil }
        return request
    }
    #expect(attempts.map(\.attemptNumber) == [1, 2])
    #expect(attempts.map(\.successful) == [false, true])
    #expect(attempts.first?.errorCode == "cancelled")
    #expect(attempts.allSatisfy { $0.errorMessage == nil && $0.durationMs >= 0 })
}
