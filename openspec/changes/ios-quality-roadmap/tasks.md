# Tasks

Execute remaining work in dependency order. Record evidence at each stage gate in [execution evidence](execution-evidence.md). Full parity stays open while any Android baseline feature lacks verification.

## 1. Stage 0 — Baseline and contracts

- [x] 1.1 Record commit, pre-existing working-tree edits, Xcode/Swift versions and available simulators; verify the baseline record identifies each precisely.
- [x] 1.2 Run strict swift-format lint and host tests; save commands, results and pre-existing failures in the baseline record.
- [x] 1.3 Run all four package/sample Debug/Release simulator/device SDK build combinations and package/sample simulator tests; save result bundles and classify failures.
- [ ] 1.4 Pin the Android release and expand the parity checklist to each public SDK feature and demo workflow. Verify each row has source, iOS disposition, owner, test and blocking reason where applicable; include metric units, cadence, clock, lifetime and privacy.
- [x] 1.5 Provision versioned video/HLS/invalid-media fixtures and controlled-server recipes; verify playback and deterministic failure reproduction from the recipes.
- [ ] 1.6 Record supported OS/device/toolchain matrix and numeric performance budgets from baseline runs; verify budgets precede feature comparisons.
- [x] 1.7 Reconcile dropped-frame and schema-version documentation; verify statements against current code and fixtures and record the Stage 0 gate decision.

## 2. Stage 1 — Completeness export fix first, then playback correctness

- [x] 2.1 Add optional delivery-incompleteness metadata to session snapshot v3 encoding/decoding with absence meaning unspecified; verify v2/v3 legacy fixtures and new-field round trips pass without conflating truncation.
- [x] 2.2 Merge the overlay host incompleteness signal into captured exports; verify incomplete-only, truncated-only, both and unspecified exports plus session switching with focused analytics/overlay tests.
- [x] 2.3 Document adapter error-to-completeness propagation and older-reader limitations; verify the sample's overflow/error path supplies and exports the affected session flag.
- [x] 2.4 Cover item start/replacement/removal, pause, completion, replay and fatal failure; verify session IDs, termination reasons and stale-callback isolation with adapter tests.
- [x] 2.5 Cover preparation/first-frame provenance, tracked seek cancellation and dropped-frame reset/duplicates; verify exact timeline and counter expectations in focused tests.
- [x] 2.6 Cover ordered delivery, overflow recovery, concurrent flush, subscriber cancellation and repeated detach; verify accepted-event ordering and unchanged host playback with integration tests.
- [x] 2.7 Define the shared schema or explicit compatibility mode. Round-trip actual Android and iOS exports through both readers and compare common fields, ordering and summaries; verify unsupported data is disclosed.
- [ ] 2.8 Execute physical-video and controlled-HLS stall scenarios; save expected/actual traces, sanitized exports and cleanup evidence, update adapter/analytics docs and record the Stage 1 gate.

- [ ] 2.9 Implement source-supported load failures and selected/available-format and switch events as their dependencies land; verify against controlled failure and multi-variant traces. Keep unsupported reasons or details open in the checklist.

## 3. Stage 2 — Bandwidth and estimator integration

- [x] 3.1 Record audited public source/availability and sample-window semantics with primary API references; verify every proposed field has a supported source or explicit unavailable state.
- [x] 3.2 Add the module test target and implement counter mapping, reset/duplicate handling and item/session cancellation; verify synthetic counter, missing-value and stale-item tests.
- [x] 3.3 Publish module integration and provenance documentation; verify its minimal optional-product sample builds.
- [ ] 3.4 Run three controlled HLS throughput levels, stall/recovery, network transition and local-media scenarios; verify declared source/window tolerances and record the Stage 2 gate.

- [ ] 3.5 Port dual EWMA, startup thresholds, reset and confidence; verify outputs against shared Android vectors and verify the native comparison's meaning independently.
- [ ] 3.6 Implement and verify host opt-in estimator-driven adaptation with a multi-variant HLS device trace. Keep this parity row blocked if only a desired bitrate limit is shown.

## 4. Stage 3 — Codec inspection

- [x] 4.1 Record supported format/capability API coverage and availability; verify selected format, available formats and device capability fields are documented separately.
- [x] 4.2 Add the module test target and implement source-supported inspection with stale-result rejection; verify known-format, unsupported, malformed and replacement tests.
- [ ] 4.3 Validate H.264/HEVC, available HDR and track-change fixtures on simulator and physical devices; compare results to fixture/selection evidence and leave unobservable details unavailable.
- [ ] 4.4 Publish optional-product usage and platform limitations; verify the documented sample and record the Stage 3 gate with device evidence.

- [ ] 4.5 Implement the device decoder catalog and selected decoder initialization/capability reporting where evidenced; verify against hardware traces and track each unsupported Android field separately.

## 5. Stage 4 — Session storage

- [ ] 5.1 Add a storage test target and actor-backed versioned snapshot-file repository with atomic replacement and durable acknowledgement; verify save/reopen and failed-replacement preservation tests.
- [ ] 5.2 Implement retrieval/listing, explicit deletion and deterministic count/byte retention with oversized-session rejection; verify ordering, limits, deletion and prior-data preservation tests.
- [ ] 5.3 Implement supported-format migration and non-destructive incompatible/corrupt-file handling; verify fixture-based migration and unsupported-version tests.
- [x] 5.4 Implement consistent snapshot export preserving truncation and delivery incompleteness; verify concurrent save/export and completeness round trips.
- [ ] 5.5 Provide the bounded storage sink bridge with explicit overflow/failure/flush semantics; verify blocked-writer and recovery tests without blocking host playback.
- [ ] 5.6 Document directory selection, retention, durability and recovery; execute restart/interrupted-write/large-session scenarios and record the Stage 4 gate.

- [x] 5.7 Verify event history survives analytics cache eviction and that sink flush/close preserve durable ordering and report failures; compare the complete storage workflow with Android.

## 6. Stage 5 — FairPlay diagnostics

- [x] 6.1 Record the supported host observation API and sanitization allowlist with public API references; verify no license/key ownership or unsupported parity claims enter the interface.
- [x] 6.2 Add a DRM test target and implement diagnostic request/attempt correlation, timing, retries, cancellation and stale-session rejection; verify deterministic host-sequence tests.
- [ ] 6.3 Implement sensitive-data exclusion before publication; verify sentinel license bodies, credentials, key material and raw identifiers do not appear in events, UI, persistence or export.
- [x] 6.4 Publish host integration and limitation documentation; verify documented mock integration and optional-product build.
- [ ] 6.5 Run authorized FairPlay success/failure/timeout/retry/cancellation/replacement scenarios on hardware; archive sanitized evidence and record the Stage 5 gate, or mark device validation blocked without closing the parity row.

- [ ] 6.6 Verify lifecycle, provisioning, key status, expiration, security and current/maximum HDCP independently; attach device evidence for each match or document the blocking difference.

## 7. Stage 6 — Overlay, ABR Explorer and reproducible diagnosis

- [ ] 7.1 Add supported bandwidth/codec/DRM state and persisted-session selection to the overlay/demo; verify state tests for unavailable, incomplete, truncated and failed data.
- [ ] 7.2 Verify selected-snapshot export, stale refresh rejection, dismissal and foreground/background behavior with simulator UI/integration tests and unchanged playback assertions.
- [ ] 7.3 Run VoiceOver, large Dynamic Type and narrow-layout checks; record pass/fail evidence for session selection, limitations and export controls.
- [ ] 7.4 Document healthy playback, controlled stall/recovery and deterministic failure recipes with expected traces and exports; verify a second developer can reproduce and diagnose all three, then record the Stage 6 gate.

- [ ] 7.5 Implement ABR Explorer and remaining Android overlay fields. Verify chart and native/custom comparison, confidence, selected/available tracks and switch decisions against matching traces and an iOS hardware run.

## 8. Stage 7 — Performance and release readiness

- [ ] 8.1 Compare diagnostics off/on, overlay closed/open and persistence off/on with fixed fixtures and repeated device runs; verify CPU, memory, stalls, event loss and storage growth against Stage 0 budgets.
- [ ] 8.2 Run long-session and repeated attach/detach tests on the supported device matrix; verify bounded resource growth and observer cleanup using captured measurements.
- [ ] 8.3 Integrate each supported SPM product independently in a clean external consumer; verify minimal examples build and supported runtime behavior executes.
- [ ] 8.4 Reconcile installation, compatibility, privacy, export/migration, attribution and changelog documentation with validated capabilities; verify each advertised module has qualifying evidence.
- [ ] 8.5 Run required CI/checks against the exact candidate commit and collect stage records; verify no unresolved release-blocking defects and record the final release-readiness decision without tagging or publishing.

- [ ] 8.6 Audit every Android baseline checklist row against test evidence. Verify no pending or blocked row is counted as parity; retain open rows even if a partial release is separately approved.

## Workflow follow-up

- Review and archive the change only after its tracked work and required evidence are complete.
- Tagging and GitHub release publication are separate authorized release actions after exact-commit validation.
