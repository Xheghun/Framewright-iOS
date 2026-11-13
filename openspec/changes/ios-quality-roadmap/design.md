# Design

## Context

See the [proposal](proposal.md) and capability specs for scope. The following findings describe the initial source review on 2026-11-13. See [execution evidence](execution-evidence.md) and [tasks](tasks.md) for implementation progress.
- Analytics, AVPlayer observation, overlay and demo contain implementations and test targets. Presence of tests and CI is not evidence of a successful current run.
- Bandwidth, codec, DRM and storage are source scaffolds with no corresponding test targets.
- iOS writes v3 and reads v2/v3. Delivery incompleteness export is implemented in tasks 2.1–2.3. The checked-in Android reader accepts only v2; bidirectional interoperability still needs a verified plan.
- Adapter docs conflict about dropped-frame support; code includes access-log counter handling. Tests documentation emphasizes v2 despite current v3 encoding.
- CI defines strict formatting, four Debug/Release simulator/device SDK builds, package simulator tests and sample tests on Xcode 16.4.
- Package deployment declarations are iOS 16, macOS 13 and Swift tools 6.0. macOS host success does not establish iOS runtime behavior.

## Goals / Non-Goals

**Goals:** match the Android SDK feature for feature and reproduce its diagnostic workflows; preserve host ownership and use equivalent native APIs; verify parity feature by feature.

**Non-Goals:** private APIs, SDK ownership of the player, offline licenses outside the Android baseline, or automated publication.

## Android parity acceptance checklist

Reference: Android working tree at commit a0e536b52288c76faaf5323d1b81df16f89abefb, using README, module docs and source; iOS working tree at e8afccbb87bc5a22e3c3cd9225b9f169e564f8c9. These are source-review statuses. Stage 0 must pin and verify the Android release used for acceptance and reconcile any source/release differences.

| Android feature | iOS at initial review | Required acceptance evidence |
|---|---|---|
| Typed analytics, live subscriptions, bounded history, sink isolation, session summaries | Implemented; comparison pending | Replay the same neutral events on both SDKs; compare publication order, failure isolation, retention and summary math. |
| Session and event JSON | Partial: iOS reads v2/v3 and writes v3; Android reader accepts v2 | Feed real exports to both readers; check event types, units, nulls, enums, completeness and failure paths. Define a shared schema or explicit compatibility export with clear loss reporting; never silently discard data. |
| Host-owned player, prepare-to-first-frame, state, rebuffering, dropped frames and terminal errors | Partial: AVPlayer attachment exists; frame evidence is host-supplied; drops are log-based | Verify matching lifecycle, timings and counts under local playback, stalls, seeks, errors and replacement. Keep readiness and confirmed rendering distinct. |
| Selected/available formats, track switches and reasons, decoder initialization, load errors | Gaps: Android adapter emits these; iOS does not have equivalent coverage | Generate a trace per Android event. Correlate actual format changes and load errors to the active item. Prove timing, identity and reason provenance before declaring parity. |
| Transfer sampling, instantaneous/fast/slow/driving estimates, confidence and default-meter comparison | Missing | Run shared sample vectors against the Android estimator; compare outputs, thresholds and reset behavior. Verify live iOS sample source and separate native comparator from the custom estimate. |
| Custom estimator drives player bitrate selection | Missing; iOS control semantics need investigation | Spike host opt-in control on a multi-variant HLS fixture; prove selected variants respond to the custom estimate under controlled conditions. A preferred bitrate setting by itself is insufficient. |
| ABR Explorer timeline, custom/default estimates, confidence, track list, selected track and decisions | Missing | Reproduce Android's workflow with a shared event trace and a real iOS stream; verify comparison, selection and decision presentation. Distinguish observed reasons from inferences. |
| Active decoder and device codec catalog | Missing | Verify selected decoder identity/classification/init time, profiles/levels and format support; separately verify catalog, ranges and adaptive/tunneled/secure capabilities where a native equivalent is proven. Record each unsupported field as a gap. |
| DRM session lifecycle, license/provisioning timing and retries | Missing | Verify equivalent host-owned FairPlay instrumentation on authorized hardware, with request kind, timing, retry and outcome retained. Investigate provisioning separately. |
| DRM key status, expiration, security level, current and max HDCP | Missing | Track each as its own acceptance row in the measurement matrix; prove supported FairPlay or output-protection observations with device evidence. Do not equate a coarse signal with a Widevine-specific value. |
| Persistent event sink, flush, session list/load/delete/export and close | Missing | Verify durable ordered events independent of the bounded analytics cache; reopen after flush, list, load, export, delete and close. Verify overflow and recovery. |
| Overlay with playback, format, bandwidth, buffer, DRM and issue details | Partial | Replay Android-equivalent diagnostic traces through the overlay and confirm every field/group, coalescing, visibility, selected session, and accessible export. |
| Demo diagnostic workflows and reproducible media cases | Partial | Match the Android demo workflows that are in the pinned baseline, including ABR Explorer and session export; verify equivalent diagnosis from both platforms' exports. |

Use four dispositions per row or subfeature: verified match, implementation pending, investigation pending, blocked. A platform difference can still match if the observable feature is proven; an absent or unverified feature cannot. Each gap carries the Android reference, iOS approach, owner, verification target and blocking reason. Extend this checklist when the pinned baseline reveals additional subfeatures. Full parity requires every baseline feature to be verified; an explicitly approved partial release does not change the parity target.

## Decisions

### 1. Use sequential stages with explicit gates

Order: baseline → existing playback correctness → bandwidth → codec → storage → DRM → integrated presentation → release. Existing modules must be trustworthy before new telemetry increases event volume. Implement one stage at a time and record its acceptance evidence before moving on. An all-modules-at-once implementation obscures attribution of failures and is rejected.

### 2. Fix delivery completeness first

The first implementation slice adds an optional additive delivery-incompleteness field to the v3 session envelope, distinct from truncated. Absence means legacy/unspecified delivery completeness, not proof of complete collection. Decode/encode preserves the field; the overlay's host-supplied incomplete signal is merged into the captured export snapshot. Pipeline overflow hooks must propagate or document responsibility for supplying the signal. Preserve v2 reading and default source compatibility. Add tests showing truncation and delivery incompleteness independently and together, plus older fixtures. Collapsing both into truncated would misstate why data is missing; that alternative is rejected.

### 3. Preserve module and observation boundaries

Analytics remains independent of AVFoundation and SwiftUI. Optional modules consume existing analytics contracts and own only their observations. Adapter and UI remain main-actor-facing; ordered publication remains serialized. Storage uses a serialized writer and a bounded event-sink bridge with failure reporting and flush/close acknowledgements. Verify the durable stream is independent of analytics cache eviction; enqueueing is not durable completion.

### 4. Use versioned atomic session files initially

Persist complete accepted event history in a versioned local envelope, using atomic commits and a single serialized writer. Prototype write amplification; keep the storage interface independent of the backend. Derive session listings from committed files to avoid a second index transaction. Use deterministic oldest-committed eviction with configurable count/byte limits. Expose an explicit directory and retention configuration; the demo supplies its policy. Reject a snapshot larger than the configured budget without evicting valid prior data. Test interrupt/reopen behavior rather than promising crash durability from an API call alone. A database adds dependency/migration overhead before query needs justify it and is deferred.

### 5. Audit public measurement sources before implementing mappings

Port Android's dual-EWMA algorithm against shared vectors, then qualify iOS inputs and a native comparison source. Apple's [access log](https://developer.apple.com/documentation/avfoundation/avplayeritemaccesslogevent) describes observed throughput and indicated media bitrate separately; neither can stand in for a native ABR estimate without evidence. [preferredPeakBitRate](https://developer.apple.com/documentation/avfoundation/avplayeritem/preferredpeakbitrate) is a desired limit; a device spike must prove the custom estimate's influence on selected variants. Codec inspection separates asset metadata, current selection, decoder identity and capabilities. Use [FairPlay content-key APIs](https://developer.apple.com/documentation/avfoundation/avcontentkey) and host hooks where supported. Audit sources on the supported OS matrix. Never fabricate a value; if an equivalent cannot be established, leave the feature open as a parity gap.

### 6. Treat device evidence as a separate deliverable

Unit tests validate reducers, counters, contracts, persistence and redaction. Simulator tests validate integration and UI. Physical devices validate real video, network transitions, codec claims, FairPlay and performance. External-consumer tests validate distribution. No category substitutes for another. Use authorized local fixtures and a controllable HLS server, not public internet availability as a deterministic assertion.

## Staged execution and acceptance

### Stage 0 — Reproducible baseline

Pin the Android reference release and commit. Expand the parity checklist to individual Android events, metrics, APIs and demo workflows. Capture current commit and working-tree state, toolchain, lint, host tests, all four SDK/configuration builds, package simulator tests and demo tests. Record pre-existing failures separately. Define a source/units/cadence/clock/lifetime/privacy matrix for all promised metrics. Reconcile dropped-frame/schema docs. Provision versioned local video, HLS and invalid-media fixtures, plus controlled-server settings. Select minimum-supported and current-supported iOS/device coverage and record numeric performance budgets before feature measurements.

**Gate:** reproducible baseline results, fixture inventory, supported-version matrix and signed-off measurement/evidence contracts. Baseline failure is not silently waived by later feature success.

### Stage 1 — Existing diagnostics and completeness

Retain the merged completeness slice. Verify item start/replacement/removal, pause/resume, fatal error, completion/replay, tracked seeks, native timeline discontinuities, first-frame readiness/render distinction, dropped-frame resets, stale callbacks, overflow/flush/recovery, cancellation and detach ownership. Exercise actual Android and iOS readers with exchanged fixtures; verify the common schema and loss behavior. Add the missing adapter event producers after their bandwidth and codec dependencies are ready; keep each producer's parity row open until its trace passes.

**Gate:** deterministic scenario expectations match event traces and summaries; real video and controlled-stall runs exist; exports disclose independent truncation/loss states; repeated detach leaves playback functional. Save tests, sanitized exports and observer-lifetime evidence.

### Stage 2 — Bandwidth

Implement audited measurement mappings, reset/delta logic, item attribution and cleanup with a dedicated test target. Port the dual-EWMA estimator, confidence and default comparison, and verify the host opt-in path from estimate to observed bitrate selection. Validate synthetic counters and HLS at at least three controlled throughput levels, stall/recovery, network changes and local media without telemetry. Define comparison tolerances from the selected source/window and fixture timing before asserting results.

**Gate:** source comparison meets declared tolerance, shared estimator vectors match, and hardware traces establish estimator-driven selection. Missing values stay unknown; missing native comparison or control evidence leaves the corresponding parity row open.

### Stage 3 — Codec

Add a dedicated test target for selected/available format and switch events, decoder initialization, selected decoder capabilities, and the on-demand device catalog. Keep unsupported Android fields as individual gaps. Test known H.264/HEVC fixtures, available HDR variants, alternative/changed tracks, malformed assets and unsupported values. Device-specific claims need hardware runs, not simulator inference.

**Gate:** metadata, selected decoder and device catalog claims match fixtures and device evidence. Unsupported decoder details remain unknown and their parity rows stay open; failed or stale inspection cannot affect playback or current item state.

### Stage 4 — Storage

Implement Decision 4 and the required sink bridge from Decision 3. Add migration/read compatibility, durable acknowledgement, deletion, retention, snapshot export, incomplete-state preservation and error reporting. Add restart, concurrent save/export, interrupted replacement, write failure, corrupt file, unsupported-version, large-session and retention tests.

**Gate:** acknowledged commits survive reopen and analytics cache eviction; failed replacements preserve prior committed data; count/byte limits hold; exports decode consistently; disk failures cannot change playback or falsely confirm persistence.

### Stage 5 — FairPlay hooks

Implement FairPlay session, request lifecycle/timing/retry/error and supported key/output-protection observations with diagnostic identifiers and allowlisted sanitized fields. Keep provisioning, key status, expiration, security level and both HDCP values as separate gap decisions. Add dedicated validation/redaction tests. Exercise success, timeout, retry, cancellation and item replacement using authorized FairPlay media/service on physical hardware.

**Gate:** no license/key ownership changes and no secrets in events/storage/export. If test credentials/media are unavailable, record runtime validation blocked; mock success cannot qualify a device-supported release claim.

### Stage 6 — Overlay, sample and diagnosis scenarios

Integrate the full overlay feature inventory, persisted-session browsing and ABR Explorer; keep unavailable, incomplete, truncated and failed states distinct. Verify refresh cancellation, background/foreground, session switching, sharing and teardown. Run VoiceOver, large Dynamic Type and narrow layouts. Publish healthy playback, controlled network-stall/recovery and deterministic playback-failure scenarios with expected timelines and sanitized exports.

**Gate:** overlay and ABR Explorer match the pinned Android feature checklist; another developer can reproduce each scenario and explain its outcome using the export; old refreshes cannot replace new session state; controls remain accessible. FairPlay scenarios are additional and conditional on Stage 5 device evidence.

### Stage 7 — Performance and release

Compare diagnostics off/on, overlay closed/open and storage off/on on representative devices using fixed assets and repeated runs. Include long playback and repeated attach/detach. Measure CPU, memory, playback stalls, diagnostic loss/queue pressure and storage growth against Stage 0 budgets. Verify product-by-product SPM selection and a clean external consumer, supported versions, exact-commit CI, docs/privacy/attribution/changelog and manual release procedure.

**Gate:** agreed budgets met, all promised capabilities have qualifying evidence, no unresolved release-blocking defects, and exact release commit passes checks before tagging. An SDK build is not a physical-device test. Full parity cannot pass while any baseline feature is pending, unverified or blocked. A separately approved partial release must list its gaps and cannot close the parity change.

## Risks / Trade-offs

- Unobservable iOS measurements → keep unknown values and provenance; document platform differences.
- New completeness field ignored by older readers → additive v3 field, compatibility fixtures, documentation that older readers cannot assess delivery loss.
- Synchronous sinks can block publication → queued bounded storage bridge, explicit flush and overflow reporting.
- Snapshot files increase rewrite cost → measure session-size/I/O budgets; retain the repository boundary if a database becomes justified later.
- Real-network/FairPlay tests need controlled infrastructure → version fixtures, record server settings, mark missing device evidence blocked.
- A wide roadmap can become an oversized patch → stage-level review and evidence; stop at a failed gate.

## Migration Plan

1. Pin the Android baseline and review feature-level acceptance requirements.
2. Preserve the merged completeness export slice and verify bidirectional compatibility before declaring export parity.
3. Implement remaining stages in order, preserving optional product selection and existing consumer APIs where possible.
4. Keep old session exports readable; reject unsupported on-disk versions without destructive overwrite.
5. Roll back optional integration by detaching/disabling that module while retaining prior committed exports. A code rollback must not rewrite newer persisted formats it cannot read.
6. Tag/publish only as a separately authorized release action after the final gate.

## Evidence Record

For each stage record commit, dirty-tree notes, OS/device/toolchain, fixture versions, command/result summaries, result-bundle paths, expected versus actual event traces, sanitized exports, performance measurements where relevant, known gaps and pass/fail decision. Planning validation and runtime verification are separate. No application tests have been executed as part of preparing these artifacts.
