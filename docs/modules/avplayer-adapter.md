# AVPlayer adapter

Product: `FramewrightAVPlayerAdapter`

Attach diagnostics to an existing `AVPlayer`. The application owns playback controls, item assignment, presentation, and audio-session policy. The adapter observes the player and publishes events to `FramewrightAnalytics`.

## Integration

Create and retain the adapter on the main actor for the playback owner's lifetime. Perform player mutations on the main actor as well.

```swift
import AVFoundation
import FramewrightAnalytics
import FramewrightAVPlayerAdapter

let pipeline = try DiagnosticEventPipeline()
let diagnostics = try FramewrightAVPlayer.attach(
    player: player,
    pipeline: pipeline,
    sessionId: "playback-1"
)

let item = AVPlayerItem(url: mediaURL)
try diagnostics.recordPreparationStarted(for: item)
player.replaceCurrentItem(with: item)
player.play()
```

Use a unique session ID, or omit it to generate one. Subscribe to the pipeline before attachment if live consumers need the initial session event. Retained events remain available through the pipeline regardless of live subscriptions.

```swift
diagnostics.detach()
await diagnostics.flush()
```

Detaching ends the active session and removes observations. It does not pause playback, replace the item, change the audio session, or close the supplied pipeline. Repeated detachment is safe. Deallocation also removes observations and queues a session end; use explicit detachment and `flush()` when export must include that event.

`flush()` waits for events already accepted by the adapter. It does not wait for future player callbacks or playback completion. Clear retained pipeline sessions when no longer needed.

## Sessions

- The first non-nil current item starts the initial session. Attaching with no item waits for one.
- Replacing or removing the current item ends the active session with `.replaced`. Each replacement starts a fresh session ID.
- Natural completion ends with `.playbackEnded`; item/player failure records a fatal error and ends with `.error`.
- Pausing does not end a session. Use `endSession(reason:)` for application-defined boundaries.
- Replaying the same item requires `startSession()` before playback. Completion does not automatically start another session.

`activeSessionID` identifies the current session. `playerState` uses analytics' idle/buffering/ready/ended states; paused ready items remain `.ready`. The schema has no separate pause or playback-state-change event.

## First-frame timing

Preparation time is only available when the host calls `recordPreparationStarted(for:)`. If the presentation component provides a confirmed rendering signal, forward it with `recordFirstFrame(for:)`. The adapter rejects duplicate, stale-item, and untracked first-frame reports.

`AVPlayer.timeControlStatus == .playing` and `AVPlayerItem.status == .readyToPlay` do not establish that a video frame was rendered. Without a host rendering signal, first-frame timing and first-frame-dependent rebuffer summaries remain unavailable. Audio playback does not generate synthetic video-frame events.

## Buffering and seeks

After a reported first frame, waiting to minimize stalls or evaluate buffering begins a rebuffer interval. Returning to playing completes it. Startup waits, waits with no item, and explicitly tracked seeks are excluded. Pausing abandons the open interval so paused time is not counted; terminal session events close an active interval.

Track application-controlled seeks around the host's seek operation:

```swift
let token = try diagnostics.beginSeek(for: item)
player.seek(to: target) { _ in
    Task { @MainActor in diagnostics.endSeek(token) }
}
```

Always complete the token, including cancelled seeks. A stale completion cannot end a newer seek or affect a replacement item. The adapter does not infer seek intent from time jumps. Untracked seeks may appear as buffering, and stalls that do not transition AVPlayer into a buffering wait are not measured.

## Configuration

`AVPlayerDiagnosticsConfiguration` accepts application/device labels, URI sanitization, error-message inclusion, and an `onDiagnosticsError` handler. Defaults remove URL credentials, query strings, and fragments; local file locations and non-HTTP URLs are redacted. Paths remain visible on HTTP URLs; supply a custom sanitizer when those contain private data. Error messages are omitted by default.

The diagnostics-error handler reports internal validation failures, closed pipelines, and sink failures. It does not change playback. Pipeline sinks must return quickly; slow sinks delay diagnostic delivery.

## Coverage

| Signal | Output |
| --- | --- |
| Current-item changes | Session start/end |
| Buffering wait / resume | Rebuffer start/end, subject to the rules above |
| Item/player failure | Playback error and session end |
| Natural completion | Session end |
| Host preparation/rendering hooks | First-frame timing |

Codec, DRM, track-selection, transfer, and dropped-frame measurements are not emitted by this adapter version.

Reference: Apple's [playback-control states](https://developer.apple.com/documentation/avfoundation/avplayer/timecontrolstatus-swift.enum), [item notifications](https://developer.apple.com/documentation/avfoundation/avplayeritem), and [display-readiness semantics](https://developer.apple.com/documentation/avfoundation/avplayerlayer/isreadyfordisplay).
