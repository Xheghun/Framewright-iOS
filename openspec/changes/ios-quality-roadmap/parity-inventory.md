# Android v0.1.1 → iOS parity inventory

Android reference: [v0.1.1](https://github.com/Xheghun/Framewright/releases/tag/v0.1.1), commit 578a502cd90201a13a88dad6d9d95731eb5dd39a. iOS reference: e8afccbb87bc5a22e3c3cd9225b9f169e564f8c9. This is a first-pass source inventory, not a completed API feasibility audit or device verification. All Android features stay in scope. Owners below are workstreams, not assigned individuals.

Shared metadata: timestampMs is wall-clock epoch milliseconds; elapsedRealtimeMs and measured durations use monotonic milliseconds; sessionId and eventId identify diagnostic records. iOS captures wall time and system uptime at emission. Rows apply only to their active item/session; detach and stale callbacks must not change later sessions. Redact credentials, query/fragment and private locations; avoid raw DRM identifiers, keys, license payloads, and raw error text by default. Unknown values must retain provenance; a missing value cannot count as a measured zero or a parity pass.

| Android event | iOS production source / disposition | Units, cadence and open verification | Owner / test |
|---|---|---|---|
| SESSION_START | Implemented; AVPlayer item/host session | One per session; sanitized URI and configured device/OS/app labels; prove DRM scheme propagation when protected playback lands | Adapter / start, replace, replay trace |
| SESSION_END | Implemented; adapter session boundary | Duration ms from monotonic start; prove reason mapping including removal, fatal failure, explicit end and release | Adapter / ordered terminal traces |
| RENDER_FIRST_FRAME | Host supplied | Prepare-to-signal ms, once per session; readiness and confirmed rendering are distinct | Adapter / hardware video and stale/duplicate hook tests |
| REBUFFER_START | Derived from AVPlayer buffering waits and contiguous loaded ranges | Buffered ms at start; after eligible first-frame signal, excludes startup and tracked seeks; zero fallback for missing/invalid range needs review | Adapter / controlled stall vs seek and missing-buffer trace |
| REBUFFER_END | Derived from playback state and monotonic stall interval | Duration ms per completed interval; verify pause, end and replacement semantics | Adapter / stall/recovery trace |
| TRACK_SWITCH | Missing producer | Bitrate bits/s, buffer ms, selection and available formats, reason; reason provenance unresolved | Adapter/codec/bandwidth / multi-variant trace, initial and manual selection |
| DECODER_INIT | Missing producer | Init duration ms per decoder init; identity, implementation classification and format support need independent evidence | Codec / decoder identity vs codec metadata on hardware |
| DROPPED_FRAMES | Derived from AVPlayer access-log counter deltas | Count and elapsed ms; samples on log/state/termination notifications, no sample when counter unavailable | Adapter / repeated reads, reset and replay traces |
| LOAD_ERROR | Missing producer | Per load failure: sanitized URI, HTTP status/class, retry count and cancellation; do not substitute a fatal playback error | Adapter / controlled HTTP failure and retry trace |
| DRM_KEY_STATUS | Missing producer | Per change: diagnostic key identity, state, expiry epoch ms, security, current/max HDCP and newly usable key; each needs separate evidence | DRM / authorized FairPlay device state transitions |
| DRM_SESSION_EVENT | Missing producer | Per lifecycle transition: acquired, key loaded/restored/removed, released and failure; sanitized details | DRM / host hook traces and device proof |
| DRM_REQUEST | Missing producer | Per attempt: license vs provisioning, request kind, attempt number, monotonic duration ms and outcome; assess provisioning separately | DRM / authorized success/retry/failure fixtures |
| DRM_EXPIRATION_UPDATE | Missing producer | Expiry epoch ms per observed update, never derived from elapsed time | DRM / authorized expiry observation or blocked finding |
| BANDWIDTH_SAMPLE | Missing producer | Bytes, duration ms, instantaneous/fast/slow/default bits/s and dimensionless confidence per qualifying sample; driving estimate available separately in Android | Bandwidth / shared estimator vectors and live HLS input verification |
| PLAYBACK_ERROR | Implemented for observed fatal item/player failures | Per failure; code and optional sanitized message, with fatal flag; verify recoverable error coverage separately | Adapter / invalid media and recoverable failure scenarios |

iOS additionally emits PLAYBACK_STATE_CHANGED and POSITION_DISCONTINUITY; preserve them in native exports and disclose any loss in a compatibility export.

| Android SDK or demo behavior | iOS disposition | Owner / acceptance |
|---|---|---|
| Bounded analytics, ordered publication, live subscriptions, sink failure isolation, snapshots and summary math | Implemented; cross-runtime behavior needs verification | Analytics / same ordered inputs, shared summary vectors and overflow/sink failure checks |
| Event and session JSON, malformed input behavior | Partial: Android v2 reader; iOS v2/v3 reader and v3 writer | Analytics / real exports through both readers, units, enums, unknown values, loss metadata and failure modes |
| Prepare/attach/detach, snapshot, summary and in-memory export while player stays host-owned | Implemented; trace parity pending | Adapter / host lifecycle with and without subscribers, teardown and preserved playback |
| Custom dual EWMA, sample qualification, reset, confidence and native comparison; transfer-listener and estimate snapshot behavior including time to first byte | Missing | Bandwidth / shared inputs against Android outputs, API source audit and session/network transition traces |
| Custom estimate actually drives adaptive selection | Missing; public iOS control equivalence unverified | Bandwidth / opt-in hardware A/B on identical HLS profile; prove selected variant changes rather than only setting a limit |
| Device decoder list and selected-decoder classification, profiles, ranges, alignment, instance limits, adaptive/secure/tunneled support | Missing; no equivalence assumed from asset metadata | Codec / independently verify each field, document blocked rows individually |
| Durable sink, ordered history independent of cache, flush and close, in-memory test mode, session list/load/delete/export | Missing | Storage / cache eviction and reopen, failure/overflow, ordering and lifecycle tests |
| Protected source host integration and redacted lifecycle, request and output diagnostics | Missing | DRM / public API audit, authorized FairPlay hardware and secret exclusion from all outputs |
| Overlay status/startup, format/codec, bandwidth, buffer/rebuffer, dropped frames, DRM and last issue; toggle and update coalescing | Partial: core playback/metrics and export implemented | Overlay / shared trace snapshots, session switch, visibility, update cadence and accessibility |
| ABR Explorer custom/default comparison chart, confidence, variant list/selection and decision detail | Missing | Demo/bandwidth / shared trace rendering plus real selection changes on hardware |
| Demo source switch between clear HLS and protected playback | Partial: clear playback, no FairPlay demo | Demo/DRM / clear and protected fixture switching with isolated sessions; track protocol/container differences separately |
| Share the latest persisted session after flush | Partial: in-memory export only | Demo/storage / reopen, select latest committed session, share and verify ordered interoperable JSON |

Evidence sources: Android tagged analytics event model, Media3 adapter and module docs, bandwidth meter and dual EWMA, codec/DRM/storage implementation, overlay models, and demo MainActivity/ABR Explorer. iOS sources: FramewrightAVPlayer, PlaybackSessionState, AVPlayerDiagnosticsConfiguration, DiagnosticEventJSONCodec, SessionSummaryCalculator, overlay and example app. Individual source availability and physical-device claims remain pending.
