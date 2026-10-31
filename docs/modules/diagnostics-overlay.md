# Diagnostics overlay

Add the `FramewrightDiagnosticsOverlay` SPM product alongside analytics and the player adapter.

```swift
import FramewrightDiagnosticsOverlay

FramewrightDiagnosticsOverlay(
    pipeline: pipeline,
    sessionID: sessionID,
    incomplete: diagnosticsIncomplete
)
```

Place the view beside the player or in a SwiftUI `.overlay(alignment:)`. Its compact button opens session details, metrics, event JSON, and a JSON file exporter. The host selects the session and passes any known delivery failure through `incomplete`. Changing the session or pipeline restarts observation. Refreshes pause while the scene is inactive. The view never controls playback or clears history.

`DiagnosticsModel.observe(pipeline:sessionID:)` also supports custom UI. Run it in a cancellable task. It refreshes the selected retained snapshot every 250 ms and updates state only when the snapshot changes. A cancelled observation cannot replace a newer session. Invalid metric totals produce an error and observation continues, allowing recovery after history is cleared or evicted. Cancellation stops refreshes without closing the shared pipeline or affecting other subscribers. This uses retained history rather than live event delivery; configure pipeline retention to bound memory and export size. The host remains responsible for clearing old sessions.

Metrics describe retained events. Truncated history is labeled. First-frame and rebuffer counts remain unavailable without first-frame instrumentation; dropped frames remain unavailable until reported. Missing device metadata is shown as unavailable. Exports capture the displayed snapshot, which can lag publication by one refresh interval, and retain its truncation flag.

The sheet supports Dynamic Type, text selection, and labeled accessibility controls. Test device-specific measurements and VoiceOver in the integrating application.
