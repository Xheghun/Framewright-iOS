import Foundation
import FramewrightAnalytics

@MainActor
final class OrderedEventWriter {
    private nonisolated let buffer: DeliveryBuffer
    private let worker: Task<Void, Never>

    init(
        pipeline: DiagnosticEventPipeline, capacity: Int = 1_024,
        onError: @escaping @MainActor @Sendable (any Error) -> Void
    ) {
        let buffer = DeliveryBuffer(pipeline: pipeline, capacity: capacity)
        self.buffer = buffer
        worker = Task {
            for await batch in buffer.stream {
                for event in batch.events {
                    let result = await batch.pipeline.publish(event)
                    if !result.recorded { onError(AVPlayerDiagnosticsError.pipelineClosed) }
                    if result.sinkFailureCount > 0 {
                        onError(AVPlayerDiagnosticsError.sinkFailures(result.sinkFailureCount))
                    }
                }
                buffer.complete(batch)
            }
        }
        self.onError = onError
    }

    private nonisolated let onError: @MainActor @Sendable (any Error) -> Void

    func setPipeline(_ pipeline: DiagnosticEventPipeline) throws { try buffer.setPipeline(pipeline) }
    var hasOverflowed: Bool { buffer.hasOverflowed }
    var isDrained: Bool { buffer.isDrained }

    nonisolated func write(_ events: [DiagnosticEvent]) {
        if buffer.write(events) {
            let capacity = buffer.capacity
            let handler = onError
            Task { @MainActor in handler(AVPlayerDiagnosticsError.eventQueueOverflow(capacity: capacity)) }
        }
    }

    func flush() async { await buffer.flush() }
    nonisolated func finish() { buffer.finish() }
    func waitUntilFinished() async { await worker.value }
    deinit { buffer.finish() }
}

// The lock also protects writes from the adapter's nonisolated deinitializer.
private final class DeliveryBuffer: @unchecked Sendable {
    struct Batch: Sendable {
        let sequence: UInt64
        let events: [DiagnosticEvent]
        let pipeline: DiagnosticEventPipeline
    }

    let capacity: Int
    let stream: AsyncStream<Batch>
    private let continuation: AsyncStream<Batch>.Continuation
    private let lock = NSLock()
    private var pipeline: DiagnosticEventPipeline
    private var pending = 0
    private var submitted: UInt64 = 0
    private var completed: UInt64 = 0
    private var closed = false
    private var overflowed = false
    private var waiters: [(UInt64, CheckedContinuation<Void, Never>)] = []

    init(pipeline: DiagnosticEventPipeline, capacity: Int) {
        precondition(capacity > 0)
        self.pipeline = pipeline
        self.capacity = capacity
        let pair = AsyncStream<Batch>.makeStream(bufferingPolicy: .bufferingOldest(capacity))
        stream = pair.stream
        continuation = pair.continuation
    }

    var hasOverflowed: Bool { lock.withLock { overflowed } }
    var isDrained: Bool { lock.withLock { pending == 0 } }

    func setPipeline(_ pipeline: DiagnosticEventPipeline) throws {
        try lock.withLock {
            guard !closed else { throw AVPlayerDiagnosticsError.deliveryPending }
            self.pipeline = pipeline
        }
    }

    // A batch is accepted atomically, including the events currently being published.
    func write(_ events: [DiagnosticEvent]) -> Bool {
        lock.withLock {
            guard !closed, !events.isEmpty else { return false }
            guard events.count <= capacity - pending else {
                closed = true
                overflowed = true
                continuation.finish()
                return true
            }
            pending += events.count
            submitted += 1
            continuation.yield(Batch(sequence: submitted, events: events, pipeline: pipeline))
            return false
        }
    }

    func complete(_ batch: Batch) {
        let ready = lock.withLock {
            pending -= batch.events.count
            completed = batch.sequence
            let ready = waiters.filter { $0.0 <= completed }
            waiters.removeAll { $0.0 <= completed }
            return ready
        }
        for (_, waiter) in ready { waiter.resume() }
    }

    func flush() async {
        await withCheckedContinuation { waiter in
            let ready = lock.withLock {
                if submitted == completed { return true }
                waiters.append((submitted, waiter))
                return false
            }
            if ready { waiter.resume() }
        }
    }

    func finish() {
        lock.withLock {
            closed = true
            continuation.finish()
        }
    }
}
