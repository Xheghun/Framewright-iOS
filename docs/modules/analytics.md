# Analytics

Product: `FramewrightAnalytics`

Analytics defines immutable diagnostic events, bounded session history, live subscriptions, summaries, and schema-versioned JSON. It imports no AVPlayer or SwiftUI APIs. Applications and adapters supply events; analytics does not observe playback or infer session boundaries.

## Publish events

```swift
import FramewrightAnalytics

let pipeline = try DiagnosticEventPipeline()
let metadata = try DiagnosticEventMetadata(
    sessionId: "playback-1",
    eventId: "first-frame-1",
    timestampMs: 1_700_000_000_000,
    elapsedRealtimeMs: 2_000,
    playerState: .ready
)
let event = DiagnosticEvent(
    metadata: metadata,
    payload: .renderFirstFrame(try RenderFirstFramePayload(elapsedSincePrepareMs: 250))
)
let result = await pipeline.publish(event)
let snapshot = try await pipeline.snapshot(sessionId: "playback-1")
let summary = try SessionSummaryCalculator().calculate(snapshot)
let json = try await pipeline.exportSessionJSON(sessionId: "playback-1")
```

Use a distinct session ID per playback session and a distinct event ID per event. `timestampMs` is Unix epoch time; `elapsedRealtimeMs` is monotonic time in milliseconds from the producer's chosen origin. All events in a session must use the same monotonic origin. Durations use milliseconds, bandwidth and bitrate use bits per second, and transfer sizes use bytes.

Events are retained in publication order. The library neither sorts timestamps nor deduplicates event IDs. It does not automatically create start/end events or close a session on a fatal error: those are adapter responsibilities.

## Live subscriptions and lifetime

```swift
let subscription = await pipeline.subscribe()
let consumer = Task {
    for await event in subscription.events {
        print(event.type)
    }
}

// When the observation owner is finished:
consumer.cancel()
await pipeline.unsubscribe(subscription.id)
await pipeline.close()
```

Each subscription has its own bounded buffer, with capacity 128 by default and no replay. Subscribe before publishing events that a live consumer must see. Use one iterator per subscription; create another subscription for another observer.

Publishing records history first, calls sinks, then yields to live subscribers. A full subscriber buffer drops the incoming event for that subscriber; faster subscribers continue independently. Publication never waits for consumers. `PublishResult.liveDelivery` reports `.dropped` if any subscriber dropped the event, `.delivered` if at least one accepted it without any drops, or `.noSubscribers` when no active subscriber accepted it. `droppedLiveEventCount` counts affected publications, not individual subscriber losses.

Cancellation removes the subscription asynchronously. Explicit `unsubscribe` gives the owner a deterministic cleanup point. `close` finishes all streams, is safe to repeat, and rejects later publication with `recorded == false` and `.closed`. Buffered events can still drain after a stream is finished. Snapshots remain available after closing. Clear retained sessions when they are no longer needed.

The pipeline is an actor. Within a publication there are no suspension points, so history, sink invocation, and live delivery preserve the same order. Concurrent callers are serialized in arrival order, which is not necessarily their task creation order.

## Sinks and retention

Implement `DiagnosticEventSink` to receive events for storage or logging. Sinks must be `Sendable` and return quickly; blocking work delays the pipeline. Sink errors increment `PublishResult.sinkFailureCount` and do not prevent history recording, delivery to other sinks, or live publication. A sink that needs detailed failure reporting should log or report its own error before throwing.

`SessionAggregator` is a value type for synchronous, caller-owned processing. The pipeline owns an instance for concurrent use. Retention defaults to 5,000 events per session; overflow replaces the oldest events and permanently marks that retained session as truncated. Snapshots are immutable copies. The number of sessions is not bounded; `clear(sessionId:)` releases a session's history. Clearing does not unsubscribe observers or change the pipeline's dropped-event counter.

## Summaries

Summary rules match Android's retained-history calculation:

- Startup time uses the first `renderFirstFrame` event's `elapsedSincePrepareMs`.
- Rebuffer count and duration include completed `rebufferEnd` events after the first frame, excluding startup buffering and incomplete buffering intervals.
- Rebuffer ratio divides completed rebuffer time by the last session-end duration, when positive.
- Switches per minute counts all track-switch events, including initial selection, against that same duration.
- Decoder initialization time is the mean of decoder-init durations; dropped frames are summed.
- A fatal playback error before the first frame marks startup failure. Nonfatal and later errors do not.

Unavailable timing ratios are `nil`, not zero. A summary carries the snapshot's `truncated` flag: its metrics describe retained data and can undercount full-session activity. Integer total overflow throws `AnalyticsValidationError` rather than trapping or silently wrapping.

## JSON and validation

`DiagnosticEventJSONCodec` encodes and decodes schema version 2. Event envelopes use `{schemaVersion, event}`; session envelopes use `{schemaVersion, sessionId, truncated, events}`. Events have flat metadata plus `type` and `payload`. Field names, uppercase enum values, and explicit nullable payload fields follow the Android schema.

All 15 Android event types are represented, including codec and DRM data. Their presence in the model does not imply those measurements are available from iOS. Adapters must not invent measurements; omit optional values, omit unavailable capability snapshots, or refrain from producing an event when required measurements are unavailable.

The codec throws `CodecError` for malformed JSON, unsupported schema versions, unknown event types, and invalid payloads. Unknown object fields are ignored. Constructors and decoding both validate nonnegative durations/counts/rates, finite ranges and confidence, positive request attempts and alignments, and nonblank identifiers. Session decoding rejects events belonging to another session. These checks are intentionally stricter than Android for some malformed inputs.

The schema fixture tests cover every event type and nested decoder capabilities. They verify JSON object equivalence, not textual key order. This is schema compatibility testing; it does not run the Android runtime or establish equivalent platform measurements.

Exports include supplied URIs, messages, and diagnostic identifiers. Analytics does not redact those fields. Producers must exclude credentials, license payloads, and other sensitive values before publishing.

## Adapter boundaries

`PlayerEventSource` is a main-actor protocol for attachment and detachment. Implementations must reject duplicate attachment, recover their detached state if setup fails, and make detachment idempotent. The protocol does not install observations or implement that state machine.

`DecoderCapabilityResolver` provides a synchronous, throwing boundary for optional codec inspection. Concrete platform implementations belong to their respective modules.

## Platform and verification

The package targets iOS 16 or later with Swift tools 6.0. macOS 13 is declared for host-side compilation and testing of the player-independent analytics module; this does not establish macOS support for future UI or player adapters.

Run `swift test` for host tests, or use Xcode's `Framewright-Package` scheme to run the same tests on an iOS simulator. CI runs simulator tests and strict Swift style checks alongside Debug/Release simulator/device builds.
