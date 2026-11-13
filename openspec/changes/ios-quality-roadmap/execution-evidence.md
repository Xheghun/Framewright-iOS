# Android parity execution evidence

Android reference [v0.1.1](https://github.com/Xheghun/Framewright/releases/tag/v0.1.1) at `578a502cd90201a13a88dad6d9d95731eb5dd39a`. See the [Stage 0 baseline](stage-0-evidence.md) for the original matrix and [tasks](tasks.md) for verification status.

| Area | Verified | Open |
| --- | --- | --- |
| Playback | Local playback and failure, lifecycle and cleanup, timing provenance, counter handling, and ordered delivery. The synthetic HLS master advanced in the simulator and invalid media produced terminal diagnostics. The server logged injected HTTP 503 responses. | Physical playback, measured stall/recovery, and controlled network transitions. |
| Session export | The tagged Android writer produced the checked-in fixture. Swift preserved its 100 ms startup summary. The tagged Android reader accepted the explicit iOS v2 export with event order and timing intact. Conversion loss is returned separately. | Broader equivalence across diagnostic workflows. |
| Bandwidth | Six default Android estimator vectors match Swift. Tests cover counter deltas, resets, replaced items, and local media. The simulator exercised 600, 1400, and 3200 kb/s per-response profiles. The demo shows reported variant switches when available. | Aggregate throughput, native ABR estimate and reasons, and proof that the custom estimate drives rendition selection. |
| Codec | A known H.264 fixture reports 640×360 at 24 fps. Tests cover malformed media, stale results after item replacement, and the three declared HLS variants. | Selected decoder identity and initialization, HEVC/HDR, catalog, and hardware proof. |
| FairPlay | Tests exercise typed outcomes, cancellation, retries, lifecycle transitions, and stale tokens. | Authorized FairPlay playback, provisioning, key status and expiration, security, and HDCP. |
| Storage | Flush/reopen, retention-limit rejection, cache-independent persistence, ordered committed exports, and preservation of completeness metadata. The demo reopened a session with ordered start and end events. | Automatic eviction, migration, and storage performance budgets. |
| Package integration | Each of the seven SPM products built and ran from a separate minimal macOS consumer. | Release compatibility across the declared toolchain and iOS deployment range. |

The implementation passed 82 host tests with two fixture tests skipped, all 84 package tests on iOS 26.5 with the HLS fixture, and eight demo tests on iOS 18.6. The [test guide](../../../Tests/README.md) and [fixture recipe](../../../Tests/MediaFixtures/README.md) describe how to rerun the checks. The simulator runs leave physical-device acceptance and Stage 0 open.
