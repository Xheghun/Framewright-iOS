# Tests

`FramewrightAnalyticsTests` uses Swift Testing and covers event validation, schema-v2 JSON, retained history, summary calculations, sink failure isolation, concurrent publication, live buffering, and subscription lifetime.

Run `swift test` on the development host, or run the `Framewright-Package` scheme's tests on an iOS simulator. CI requires test targets and fails if they are removed.

`Fixtures/schema-v2-session.json` is a hand-assembled contract fixture based on the Android codec's field names and enum values. It covers all event types, nullable fields, and nested codec capabilities; it is not an export captured from a running player.

`FramewrightAVPlayerAdapterTests` covers session state, observation cleanup, replacement, stale callbacks, redaction, and real AVPlayer playback/failure using locally generated audio. Run the same tests on an iOS simulator. Tests do not depend on remote media.

Codec availability, DRM, SwiftUI presentation, real video rendering, and network-stall behavior still require module-specific and device-level validation.
