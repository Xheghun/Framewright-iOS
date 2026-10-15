# Test strategy

No test targets or test implementations exist yet. Add module-specific test targets when behavior is introduced.

- Analytics: event ordering, session transitions, summary calculations, serialization, and invalid or missing input.
- Player adapter: attachment, detachment, item replacement, repeated cleanup, observer lifetime, and event mapping.
- Overlay: diagnostic-state reduction and SwiftUI integration.
- Optional modules: supported telemetry, unavailable values, failures, and persistence round trips.
- Integration: host-owned AVPlayer playback in the demo, simulator checks, and physical-device validation for device-dependent diagnostics.

Use Android test scenarios as behavioral references. Do not claim cross-platform metric equivalence where measurement sources differ.
