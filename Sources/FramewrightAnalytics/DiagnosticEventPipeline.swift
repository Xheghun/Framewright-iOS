import Foundation

/// Sinks run synchronously on the pipeline actor. Enqueue slow work elsewhere.
public protocol DiagnosticEventSink: Sendable {
    func record(_ event: DiagnosticEvent) throws
}

public enum LiveDelivery: Sendable, Equatable {
    case delivered
    case noSubscribers
    case dropped
    case closed
}

public struct PublishResult: Sendable, Equatable {
    public let recorded: Bool
    public let liveDelivery: LiveDelivery
    public let sinkFailureCount: Int
}

/// One independently buffered live subscriber. No historical events are replayed.
public struct DiagnosticSubscription: Sendable {
    public let id: UUID
    public let events: AsyncStream<DiagnosticEvent>
}

/// Serializes history, sink calls, and live publication without suspending midway through an event.
/// Subscribers have independent bounded buffers; slow subscribers drop new events only for themselves.
public actor DiagnosticEventPipeline {
    private var aggregator: SessionAggregator
    private let liveBufferCapacity: Int
    private let sinks: [any DiagnosticEventSink]
    private var subscribers: [UUID: AsyncStream<DiagnosticEvent>.Continuation] = [:]
    private var closed = false
    /// Counts publications dropped for at least one subscriber, not individual subscriber losses.
    public private(set) var droppedLiveEventCount = 0

    public init(
        maxEventsPerSession: Int = 5_000, liveBufferCapacity: Int = 128,
        sinks: [any DiagnosticEventSink] = []
    ) throws {
        guard liveBufferCapacity > 0 else { throw AnalyticsValidationError.invalidField("liveBufferCapacity") }
        aggregator = try SessionAggregator(maxEventsPerSession: maxEventsPerSession)
        self.liveBufferCapacity = liveBufferCapacity
        self.sinks = sinks
    }

    public func subscribe() -> DiagnosticSubscription {
        let id = UUID()
        let pair = AsyncStream<DiagnosticEvent>.makeStream(bufferingPolicy: .bufferingOldest(liveBufferCapacity))
        if closed {
            pair.continuation.finish()
        } else {
            subscribers[id] = pair.continuation
            pair.continuation.onTermination = { [weak self] _ in
                Task { await self?.unsubscribe(id) }
            }
        }
        return DiagnosticSubscription(id: id, events: pair.stream)
    }

    public func unsubscribe(_ id: UUID) { subscribers.removeValue(forKey: id)?.finish() }

    public func publish(_ event: DiagnosticEvent) -> PublishResult {
        guard !closed else { return PublishResult(recorded: false, liveDelivery: .closed, sinkFailureCount: 0) }
        aggregator.record(event)
        var failures = 0
        for sink in sinks {
            do { try sink.record(event) } catch { failures += 1 }
        }
        var delivered = false
        var dropped = false
        var terminated: [UUID] = []
        for (id, continuation) in subscribers {
            switch continuation.yield(event) {
            case .enqueued: delivered = true
            case .dropped: dropped = true
            case .terminated: terminated.append(id)
            @unknown default: dropped = true
            }
        }
        for id in terminated { subscribers.removeValue(forKey: id) }
        if dropped { droppedLiveEventCount += 1 }
        return PublishResult(
            recorded: true, liveDelivery: dropped ? .dropped : (delivered ? .delivered : .noSubscribers),
            sinkFailureCount: failures
        )
    }

    public func snapshot(sessionId: String) throws -> SessionSnapshot { try aggregator.snapshot(sessionId: sessionId) }
    public nonisolated func exportSessionJSON(sessionId: String) async throws -> String {
        let snapshot = try await snapshot(sessionId: sessionId)
        return try DiagnosticEventJSONCodec().encodeSession(snapshot)
    }
    public func clear(sessionId: String) { aggregator.clear(sessionId: sessionId) }

    /// Ends live streams and rejects further publication. Retained snapshots remain accessible.
    public func close() {
        closed = true
        let continuations = Array(subscribers.values)
        subscribers.removeAll()
        for continuation in continuations { continuation.finish() }
    }

    deinit {
        for continuation in subscribers.values { continuation.finish() }
    }
}
