# Framewright iOS implementation plan

## Objective

Build a native Swift library for iOS that preserves the Android Framewright module responsibilities and attach-first model. Distribute independently selectable products through Swift Package Manager. Use SwiftUI for diagnostics UI.

The host application creates, configures, controls, and releases its player. Framewright observes it and owns only its diagnostic resources. Detaching diagnostics must leave the player usable.

## Current scope

The package structure and analytics module are implemented. Analytics includes typed events, bounded history, summaries, live delivery, JSON serialization, and a test suite. AVPlayer attachment, lifecycle observation, and host timing hooks are implemented and documented in [AVPlayer adapter](modules/avplayer-adapter.md). The SwiftUI overlay and example app are implemented. Bandwidth, codec, DRM, and storage remain pending. The analytics contract and explicit platform differences are documented in [Analytics](modules/analytics.md).

Reference implementation: `/Users/david/AndroidStudioProjects/Framewright`.

iOS workspace: `/Users/david/XcodeProjects/Framewright`.

## Module mapping

| Android artifact | SPM product |
| --- | --- |
| `framewright-analytics` | `FramewrightAnalytics` |
| `framewright-media3-adapter` | `FramewrightAVPlayerAdapter` |
| `framewright-bandwidth-monitor` | `FramewrightBandwidthMonitor` |
| `framewright-codec-inspector` | `FramewrightCodecInspector` |
| `framewright-drm-inspector` | `FramewrightDRMInspector` |
| `framewright-diagnostics-overlay` | `FramewrightDiagnosticsOverlay` |
| `framewright-storage` | `FramewrightStorage` |

Analytics will be independent of player and UI frameworks. Each optional module depends on analytics. The overlay consumes diagnostic state rather than directly observing AVPlayer. Any additional dependency must be justified by the platform audit; matching Android responsibilities does not require copying its internal dependency graph.

## Milestone 1: behavior and platform audit

- Review Android public APIs, events, configuration, session lifecycle, summary formulas, export format, and tests.
- Define session start/end rules, player-item transitions, event ordering, time units, and unavailable-value semantics.
- Check current Apple documentation for the observations and measurements available through public APIs.
- Classify each Android diagnostic as directly supported, derived, requiring host integration, or unavailable on iOS.
- Document measurement differences, especially bandwidth estimates, codec capability reporting, and DRM visibility.
- Choose concurrency isolation, event delivery and subscriber behavior, cancellation, and observer ownership before defining the public API.
- Confirm deployment and Swift compatibility. The scaffold uses iOS 16 and Swift tools 6.0 provisionally; these are not yet a validated compatibility promise.

Exit criteria: a reviewed behavior matrix, module dependency decisions, and proposed Swift API examples. No invented parity or unsupported metrics.

## Milestone 2: analytics and AVPlayer attachment

- Implement typed events, session identifiers, aggregation, summaries, and JSON serialization.
- Implement attachment to an existing host-owned AVPlayer.
- Translate playback state, buffering, seeking, errors, and item changes using audited platform observations.
- Implement explicit cleanup and safe observer lifetimes, including repeated detachment and player replacement.
- Add module test targets as behavior arrives; adapt relevant Android scenarios rather than translating implementation details.

Exit criteria: a host can attach diagnostics, receive events for a playback session, obtain a summary, and detach without changing player ownership or breaking playback.

## Milestone 3: SwiftUI overlay and example app

- Implement observable diagnostic state and independently testable state reduction.
- Implement a SwiftUI overlay with available metrics, clear unavailable states, and accessible presentation.
- Add a minimal iOS demo that imports the local package, owns its player, and attaches the overlay.
- Exercise navigation, screen teardown, item replacement, playback failures, and multiple diagnostic subscribers.

Exit criteria: a working video playback demonstration with live diagnostics, session export, and verified cleanup. This is the first usable end-to-end milestone.

## Milestone 4: optional diagnostic modules

- Add bandwidth telemetry with documented source, units, update cadence, and distinction between observed throughput and estimates.
- Add available codec and media-format inspection; distinguish asset metadata from decoder capabilities.
- Add DRM diagnostics supported by public APIs, with explicit host hooks where needed. Exclude secrets and license payloads from routine telemetry.
- Define a persistence interface and choose a storage implementation after compatibility and lifecycle requirements are settled.
- Add persistence failure handling, retention, session retrieval, and export.

Exit criteria: each product is independently usable, tested for supported and unavailable data, and documented with platform limitations.

## Milestone 5: integration and release readiness

- Validate package consumption from a separate SwiftUI app and independently selected SPM products.
- Run Swift unit tests plus iOS simulator builds and playback integration checks.
- Validate device-dependent codec, network, and DRM behavior on physical devices with suitable test media.
- Document installation, supported versions, minimal attachment, optional modules, cleanup, privacy, and export semantics.
- Establish CI, licensing/attribution, semantic versioning, changelog, and release tagging before publishing.

Exit criteria: reproducible package integration, passing relevant checks, documented limitations, and a tagged first release.

## Validation boundaries

An empty-target host build verifies only the initial package structure. It provides no evidence of iOS API compatibility, playback behavior, performance, or device-level telemetry. Future implementation must be validated on the intended platforms.

## Decisions deferred until the audit

- Final minimum iOS and Swift versions.
- Public type names and attachment API signatures.
- Event delivery, backpressure, actor isolation, and ordering guarantees.
- Cross-platform export-schema compatibility and versioning.
- Persistence backend and retention defaults.
- Exact capability coverage for bandwidth, codec, and DRM products.
- Demo media fixtures and release repository URL.
