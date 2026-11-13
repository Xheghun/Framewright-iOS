# iOS quality and Android parity roadmap

Framewright iOS targets feature-for-feature parity with [Framewright Android v0.1.1](https://github.com/Xheghun/Framewright/releases/tag/v0.1.1) at commit `578a502cd90201a13a88dad6d9d95731eb5dd39a`. The host retains ownership of playback. Each Android feature needs equivalent observable behavior and acceptance evidence on iOS.

The [OpenSpec tasks](../openspec/changes/ios-quality-roadmap/tasks.md) are the source of truth for progress and stage gates.

| OpenSpec document | Use |
| --- | --- |
| [Proposal](../openspec/changes/ios-quality-roadmap/proposal.md) | Scope and capability specifications |
| [Design](../openspec/changes/ios-quality-roadmap/design.md) | Acceptance criteria and stage dependencies |
| [Parity inventory](../openspec/changes/ios-quality-roadmap/parity-inventory.md) | Android workflows, iOS coverage, and missing evidence |
| [API audit](../openspec/changes/ios-quality-roadmap/api-audit.md) | Measurement sources, availability, and limitations |
| [Execution evidence](../openspec/changes/ios-quality-roadmap/execution-evidence.md) | Verified behavior and remaining gaps |

The current work covers Android-compatible export, controlled HLS tests, bandwidth sampling and estimation, asset format inspection, FairPlay host hooks, file-backed session storage, and demo diagnostics. Open gates include controlled playback stalls, estimator-driven rendition selection, decoder and DRM measurements, storage migration and performance, and physical-device performance budgets. See the [test guide](../Tests/README.md) for local checks and [CI and delivery](continuous-integration.md) for release validation.
