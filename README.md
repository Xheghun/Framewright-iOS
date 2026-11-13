# Framewright for iOS

Framewright is an attach-first diagnostics toolkit for iOS video playback, distributed through Swift Package Manager. Its architecture centers on host-owned `AVPlayer` instances, with separate modules for analytics, player integration, bandwidth, codec, DRM, diagnostics UI, and persistence.

Your application retains ownership of player creation, configuration, playback control, and lifecycle.

> **Development status** · The package includes analytics, AVPlayer integration, a SwiftUI overlay, bandwidth telemetry, asset format inspection, FairPlay host hooks, and session storage. The [Android parity roadmap](docs/implementation-plan.md) tracks the remaining features and acceptance evidence.

## Modules

The package defines the following products and module responsibilities:

| Product | Purpose |
| --- | --- |
| [`FramewrightAnalytics`](docs/modules/analytics.md) | Player-independent events, aggregation, summaries, and JSON serialization |
| [`FramewrightAVPlayerAdapter`](docs/modules/avplayer-adapter.md) | AVPlayer observation and playback event mapping |
| [`FramewrightBandwidthMonitor`](docs/modules/bandwidth-monitor.md) | Bandwidth and transfer telemetry |
| [`FramewrightCodecInspector`](docs/modules/codec-inspector.md) | Media-format and codec inspection |
| [`FramewrightDRMInspector`](docs/modules/drm-inspector.md) | DRM diagnostics |
| [`FramewrightDiagnosticsOverlay`](docs/modules/diagnostics-overlay.md) | SwiftUI session metrics, event history, and export |
| [`FramewrightStorage`](docs/modules/storage.md) | Session persistence and JSON export |

Each product is declared separately so applications can select the modules they need. Feature modules depend on `FramewrightAnalytics`.

## Development

Open `Package.swift` in Xcode to work on the library, or add the repository directory as a local Swift package dependency.

The package specifies iOS 16 or later and Swift tools 6.0. The package declares macOS 13 for host-side development. See the [test guide](Tests/README.md) for simulator coverage and the roadmap for remaining release checks.

Inspect and build the package:

```sh
swift package describe
swift build
swift test
```

These commands validate the package and run its macOS tests. Use the iOS simulator schemes for integration checks.

## Contributor documentation

- [Continuous integration and delivery](docs/continuous-integration.md)
- [Implementation plan](docs/implementation-plan.md)
- [Test strategy](Tests/README.md)
- [Example app scope](Examples/README.md)

## Sample app

The [SwiftUI sample](Examples/README.md) demonstrates AVPlayer attachment, playback controls, live diagnostics, and session export using a local package dependency. Open `Examples/FramewrightDemo/FramewrightDemo.xcodeproj` in Xcode.
