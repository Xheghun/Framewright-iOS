# Framewright for iOS

Framewright is an attach-first diagnostics toolkit for iOS video playback, distributed through Swift Package Manager. Its architecture centers on host-owned `AVPlayer` instances, with separate modules for analytics, player integration, bandwidth, codec, DRM, diagnostics UI, and persistence.

Your application retains ownership of player creation, configuration, playback control, and lifecycle.

> **Development status:** Analytics, AVPlayer integration, and the SwiftUI diagnostics overlay are available. Bandwidth, codec, DRM, and storage modules remain unimplemented.

## Modules

The package defines the following products and module responsibilities:

| Product | Purpose |
| --- | --- |
| [`FramewrightAnalytics`](docs/modules/analytics.md) | Player-independent events, aggregation, summaries, and JSON serialization |
| [`FramewrightAVPlayerAdapter`](docs/modules/avplayer-adapter.md) | AVPlayer observation and playback event mapping |
| `FramewrightBandwidthMonitor` | Bandwidth and transfer telemetry |
| `FramewrightCodecInspector` | Media-format and codec inspection |
| `FramewrightDRMInspector` | DRM diagnostics |
| [`FramewrightDiagnosticsOverlay`](docs/modules/diagnostics-overlay.md) | SwiftUI session metrics, event history, and export |
| `FramewrightStorage` | Session persistence and JSON export |

Each product is declared separately so applications can select the modules they need. Feature modules depend on `FramewrightAnalytics`.

## Development

Open `Package.swift` in Xcode to work on the library, or add the repository directory as a local Swift package dependency.

The package specifies iOS 16 or later and Swift tools 6.0. macOS 13 is declared for host-side analytics testing. Release compatibility has not yet been validated.

Inspect and build the package:

```sh
swift package describe
swift build
swift test
```

These commands validate the package structure and compile the source targets on the host platform. iOS integration requires separate simulator and device validation.

## Contributor documentation

- [Continuous integration and delivery](docs/continuous-integration.md)
- [Implementation plan](docs/implementation-plan.md)
- [Test strategy](Tests/README.md)
- [Example app scope](Examples/README.md)

## Sample app

The [SwiftUI sample](Examples/README.md) demonstrates AVPlayer attachment, playback controls, live diagnostics, and session export using a local package dependency. Open `Examples/FramewrightDemo/FramewrightDemo.xcodeproj` in Xcode.
