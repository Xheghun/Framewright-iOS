import Foundation
import FramewrightAnalytics

public enum PersistentDiagnosticSinkError: Error, Equatable, Sendable {
    case invalidCapacity
    case closed
    case overflow
    case writeFailed
}

/// Enqueues synchronously and commits asynchronously in order. One sink owns writes to its store.
public final class PersistentDiagnosticSink: DiagnosticEventSink, @unchecked Sendable {
    private let state: State
    private let worker: Task<Void, Never>

    public init(store: FramewrightSessionStore, capacity: Int = 128) throws {
        guard capacity > 0 else { throw PersistentDiagnosticSinkError.invalidCapacity }
        let state = State(capacity: capacity)
        self.state = state
        worker = Task {
            for await event in state.stream {
                do {
                    try await store.append(event)
                    state.completed(failed: false)
                } catch {
                    state.completed(failed: true)
                }
            }
        }
    }

    public func record(_ event: DiagnosticEvent) throws { try state.enqueue(event) }

    /// Waits for work accepted before this call. Reports any failure in that prefix.
    public func flush() async throws { try await state.flush() }

    /// Stops accepting events, drains the queue, and reports whether all writes succeeded.
    public func close() async throws {
        state.close()
        await worker.value
        try await flush()
    }

    deinit { state.close() }

    private final class State: @unchecked Sendable {
        let stream: AsyncStream<DiagnosticEvent>
        private let continuation: AsyncStream<DiagnosticEvent>.Continuation
        private let lock = NSLock()
        private let capacity: Int
        private var submitted = 0
        private var finished = 0
        private var firstFailure: Int?
        private var closed = false
        private var waiters: [(Int, CheckedContinuation<Void, Error>)] = []

        init(capacity: Int) {
            self.capacity = capacity
            let pair = AsyncStream<DiagnosticEvent>.makeStream()
            stream = pair.stream
            continuation = pair.continuation
        }

        func enqueue(_ event: DiagnosticEvent) throws {
            try lock.withLock {
                guard !closed else { throw PersistentDiagnosticSinkError.closed }
                guard submitted - finished < capacity, submitted < Int.max else {
                    throw PersistentDiagnosticSinkError.overflow
                }
                submitted += 1
                continuation.yield(event)
            }
        }

        func completed(failed: Bool) {
            let ready = lock.withLock {
                finished += 1
                if failed, firstFailure == nil { firstFailure = finished }
                let ready = waiters.filter { $0.0 <= finished }
                waiters.removeAll { $0.0 <= finished }
                return (ready, firstFailure)
            }
            for (target, waiter) in ready.0 {
                if let failure = ready.1, failure <= target {
                    waiter.resume(throwing: PersistentDiagnosticSinkError.writeFailed)
                } else {
                    waiter.resume()
                }
            }
        }

        func flush() async throws {
            try await withCheckedThrowingContinuation { (waiter: CheckedContinuation<Void, Error>) in
                lock.withLock {
                    if finished < submitted {
                        waiters.append((submitted, waiter))
                    } else if firstFailure != nil {
                        waiter.resume(throwing: PersistentDiagnosticSinkError.writeFailed)
                    } else {
                        waiter.resume()
                    }
                }
            }
        }

        func close() {
            lock.withLock {
                guard !closed else { return }
                closed = true
                continuation.finish()
            }
        }
    }
}
