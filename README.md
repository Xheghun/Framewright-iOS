# Framewright for iOS

Planned native iOS diagnostics library for host-owned `AVPlayer` instances, distributed through Swift Package Manager. Diagnostic UI will use SwiftUI.

**Status: scaffold only.** There are no public APIs, playback observers, metrics, UI, persistence, or implemented features yet.

## Package products

| Product | Planned responsibility |
| --- | --- |
| `FramewrightAnalytics` | Events, session lifecycle, aggregation, summaries, JSON serialization |
| `FramewrightAVPlayerAdapter` | Observe a host-owned player and translate observations into diagnostic events |
| `FramewrightBandwidthMonitor` | Available bandwidth and transfer telemetry |
| `FramewrightCodecInspector` | Available media-format and codec diagnostics |
| `FramewrightDRMInspector` | Available DRM diagnostics and explicit host integration where required |
| `FramewrightDiagnosticsOverlay` | SwiftUI diagnostics driven by the event stream |
| `FramewrightStorage` | Optional session persistence and export |

Each feature target currently depends only on `FramewrightAnalytics`. Platform-specific dependencies will be decided during the API audit.

## Development

Open `Package.swift` in Xcode or add this directory as a local package to an iOS project. The provisional minimum deployment target is iOS 16, with Swift tools 6.0. Confirm compatibility during the platform audit before publishing.

`swift package describe` checks the package structure. `swift build` checks the empty targets on the host; it does not validate future iOS features.

See [the implementation plan](docs/implementation-plan.md), [test strategy](Tests/README.md), and [example app scope](Examples/README.md).
