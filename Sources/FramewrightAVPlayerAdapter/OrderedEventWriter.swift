import Foundation
import FramewrightAnalytics

@MainActor
final class OrderedEventWriter {
    private enum Command: Sendable {
        case events([DiagnosticEvent])
        case barrier(CheckedContinuation<Void, Never>)
    }

    private nonisolated let continuation: AsyncStream<Command>.Continuation
    private let worker: Task<Void, Never>

    init(
        pipeline: DiagnosticEventPipeline, after previous: OrderedEventWriter? = nil,
        onError: @escaping @MainActor @Sendable (any Error) -> Void
    ) {
        let pair = AsyncStream<Command>.makeStream()
        continuation = pair.continuation
        let predecessor = previous?.worker
        worker = Task {
            await predecessor?.value
            for await command in pair.stream {
                switch command {
                case .events(let events):
                    for event in events {
                        let result = await pipeline.publish(event)
                        if !result.recorded { onError(AVPlayerDiagnosticsError.pipelineClosed) }
                        if result.sinkFailureCount > 0 {
                            onError(AVPlayerDiagnosticsError.sinkFailures(result.sinkFailureCount))
                        }
                    }
                case .barrier(let waiter): waiter.resume()
                }
            }
        }
    }

    nonisolated func write(_ events: [DiagnosticEvent]) {
        if !events.isEmpty { continuation.yield(.events(events)) }
    }

    func flush() async {
        await withCheckedContinuation { waiter in
            if case .terminated = continuation.yield(.barrier(waiter)) { waiter.resume() }
        }
    }

    nonisolated func finish() { continuation.finish() }
    func waitUntilFinished() async { await worker.value }
    deinit { continuation.finish() }
}
