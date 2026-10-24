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

private final class BlockingDeliverySink: DiagnosticEventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var entered = false
    private let release = DispatchSemaphore(value: 0)
    var hasEntered: Bool { lock.withLock { entered } }
    func unblock() { release.signal() }
    func record(_ event: DiagnosticEvent) throws {
        let shouldBlock = lock.withLock {
            if entered { return false }
            entered = true
            return true
        }
        if shouldBlock, release.wait(timeout: .now() + 10) != .success {
            throw SinkTimeout.expired
        }
    }
    private enum SinkTimeout: Error { case expired }
}

@Test(.timeLimit(.minutes(1))) @MainActor func capacityIncludesBlockedInFlightEvents() async throws {
    let sink = BlockingDeliverySink()
    defer { sink.unblock() }
    let pipeline = try DiagnosticEventPipeline(sinks: [sink])
    var errors: [AVPlayerDiagnosticsError] = []
    let writer = OrderedEventWriter(pipeline: pipeline, capacity: 2) { error in
        if let error = error as? AVPlayerDiagnosticsError { errors.append(error) }
    }
    writer.write([try deliveryEvent("in-flight")])
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while !sink.hasEntered, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
    try #require(sink.hasEntered)
    writer.write([try deliveryEvent("queued")])
    writer.write([try deliveryEvent("rejected")])
    #expect(writer.hasOverflowed)
    #expect(!writer.isDrained)
    var flushed = false
    let flush = Task {
        await writer.flush()
        flushed = true
    }
    for _ in 0..<100 where errors.isEmpty { await Task.yield() }
    #expect(!flushed)
    #expect(errors == [.eventQueueOverflow(capacity: 2)])
    sink.unblock()
    await flush.value
    await writer.waitUntilFinished()
    #expect(try await pipeline.snapshot(sessionId: "delivery").events.map(\.eventId) == ["in-flight", "queued"])
}
