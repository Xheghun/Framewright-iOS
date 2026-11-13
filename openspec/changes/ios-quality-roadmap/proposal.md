# Proposal

## Why

At the start of the roadmap, Framewright iOS implemented analytics, AVPlayer attachment, diagnostics UI, and a sample. Bandwidth, codec, DRM, and storage began as scaffolds. The goal is feature-for-feature parity with the Android SDK and its shipped diagnostic workflows. The change maps each Android behavior to an iOS implementation and an acceptance test, and tracks any unmet behavior as a parity gap.

## What Changes

- Establish a reproducible baseline and documented iOS measurement contract before expanding functionality.
- Harden existing session lifecycle, event delivery, schema compatibility, first-frame reporting, and dropped-frame handling.
- Implement Android-equivalent diagnostic features: dual-EWMA estimation and ABR comparison, codec catalog and active format inspection, durable session storage, and FairPlay equivalents for Android DRM observations.
- Cover the Android adapter's full event surface, the Android overlay's diagnostic fields, and the ABR Explorer workflow. Exercise interoperable exports against actual readers on both platforms.
- Extend diagnostics presentation and reproducible sample scenarios to cover supported modules and incomplete data.
- Require test evidence at each stage and an independently integrated SPM consumer before release.
- Preserve host ownership of playback. For every Android feature that lacks a proven iOS route, document the gap, evidence, owner, and next investigation. Missing or unverified features block a full-parity claim.

## Capabilities

### New Capabilities

The initialized OpenSpec inventory has no existing specs. These specifications establish durable behavior for both existing and proposed iOS functionality.

- `ios-playback-diagnostics`: Session lifecycle, event ordering, timing provenance, export compatibility, and observation cleanup.
- `ios-bandwidth-telemetry`: Source-attributed throughput samples and unavailable-data behavior.
- `ios-codec-inspection`: Media-format metadata and explicitly bounded device-capability reporting.
- `ios-session-storage`: Durable retrieval, retention, migration, deletion, and consistent session export.
- `ios-drm-diagnostics`: Host-integrated FairPlay diagnostics with privacy and ownership boundaries.
- `ios-diagnostics-presentation`: Session-scoped metrics, completeness labels, export, and accessible presentation.

### Modified Capabilities

None: no main specifications exist yet.

## Impact

Targets: the seven existing SPM products, module tests, SwiftUI demo, CI, and contributor/release documentation in this repository. Swift/iOS compatibility remains to be demonstrated against the declared iOS 16 and Swift tools 6.0 baseline. New optional modules need test targets; persistence backend and supported FairPlay hooks are explicit design decisions. No new third-party dependency is selected by this proposal. Android's shipped feature set is the acceptance baseline. Native implementations can differ; matching a feature requires matching its observable behavior and proving it. Offline DRM management and SDK ownership of the player are outside the Android baseline. Estimator-driven player integration is in scope.
