import Foundation
import FramewrightAnalytics
import Testing

@testable import FramewrightAVPlayerAdapter

private func deliveryEvent(_ id: String) throws -> DiagnosticEvent {
    try DiagnosticEvent(
        metadata: DiagnosticEventMetadata(sessionId: "delivery", eventId: id, timestampMs: 0, elapsedRealtimeMs: 0),
        payload: .sessionStart(SessionStartPayload(mediaUri: "https://example.com/video")))
}

@Test @MainActor func overflowRejectsWholeBatchAndReportsOnce() async throws {
    let pipeline = try DiagnosticEventPipeline()
    var errors: [AVPlayerDiagnosticsError] = []
    let writer = OrderedEventWriter(pipeline: pipeline, capacity: 3) { error in
        if let error = error as? AVPlayerDiagnosticsError { errors.append(error) }
    }
    writer.write([try deliveryEvent("1"), try deliveryEvent("2")])
    writer.write([try deliveryEvent("3"), try deliveryEvent("4")])
    writer.write([try deliveryEvent("5")])
    #expect(writer.hasOverflowed)
    await writer.flush()
    await writer.waitUntilFinished()
    // The error callback is scheduled independently of the delivery worker.
    for _ in 0..<100 where errors.isEmpty { await Task.yield() }
    #expect(errors == [.eventQueueOverflow(capacity: 3)])
    #expect(try await pipeline.snapshot(sessionId: "delivery").events.map(\.eventId) == ["1", "2"])
    #expect(writer.isDrained)
}

@Test @MainActor func flushDoesNotConsumeEventCapacityAndPipelineChangesPreserveOrder() async throws {
    let first = try DiagnosticEventPipeline()
    let second = try DiagnosticEventPipeline()
    let writer = OrderedEventWriter(pipeline: first, capacity: 2) { _ in Issue.record("Unexpected delivery failure") }
    writer.write([try deliveryEvent("first")])
    try writer.setPipeline(second)
    writer.write([try deliveryEvent("second")])
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<20 { group.addTask { await writer.flush() } }
    }
    #expect(!writer.hasOverflowed)
    #expect(try await first.snapshot(sessionId: "delivery").events.map(\.eventId) == ["first"])
    #expect(try await second.snapshot(sessionId: "delivery").events.map(\.eventId) == ["second"])
    writer.finish()
    await writer.waitUntilFinished()
}

private final class FirstDeliverySink: DiagnosticEventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var action: (@Sendable () -> Void)?

    func onFirstDelivery(_ action: @escaping @Sendable () -> Void) {
        lock.withLock { self.action = action }
    }

    func record(_ event: DiagnosticEvent) throws {
        let action = lock.withLock {
            let action = self.action
            self.action = nil
            return action
        }
        action?()
    }
}

@Test(.timeLimit(.minutes(1))) @MainActor func capacityIncludesInFlightEvents() async throws {
    let sink = FirstDeliverySink()
    let pipeline = try DiagnosticEventPipeline(sinks: [sink])
    let errors = AsyncStream<AVPlayerDiagnosticsError>.makeStream()
    defer { errors.continuation.finish() }
    let writer = OrderedEventWriter(pipeline: pipeline, capacity: 2) { error in
        if let error = error as? AVPlayerDiagnosticsError { errors.continuation.yield(error) }
    }
    let queued = try deliveryEvent("queued")
    let rejected = try deliveryEvent("rejected")
    sink.onFirstDelivery {
        // The first event is still inside publish, so it must occupy one queue slot.
        writer.write([queued])
        writer.write([rejected])
    }
    writer.write([try deliveryEvent("in-flight")])
    await writer.flush()
    try #require(writer.hasOverflowed)
    await writer.waitUntilFinished()
    var iterator = errors.stream.makeAsyncIterator()
    #expect(await iterator.next() == .eventQueueOverflow(capacity: 2))
    #expect(writer.isDrained)
    #expect(try await pipeline.snapshot(sessionId: "delivery").events.map(\.eventId) == ["in-flight", "queued"])
}
