# Tests

`FramewrightAnalyticsTests` uses Swift Testing and covers event validation, schema-v2 JSON, retained history, summary calculations, sink failure isolation, concurrent publication, live buffering, and subscription lifetime.

Run `swift test` on the development host, or run the `Framewright-Package` scheme's tests on an iOS simulator. CI requires test targets and fails if they are removed.

`Fixtures/schema-v2-session.json` is a hand-assembled contract fixture based on the Android codec's field names and enum values. It covers all event types, nullable fields, and nested codec capabilities; it is not an export captured from a running player.

Add adapter, overlay, storage, and device-level tests alongside those modules' implementations. The current suite does not validate playback, codec availability, DRM behavior, or SwiftUI integration.
