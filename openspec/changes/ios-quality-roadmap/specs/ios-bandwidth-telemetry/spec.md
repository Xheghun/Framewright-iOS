# Spec Delta

## Purpose
Provide interpretable iOS transfer telemetry with explicit measurement sources, units, sampling windows, and unavailable states.

## ADDED Requirements

### Requirement: Samples disclose source and meaning
Telemetry SHALL distinguish observed transfer throughput, indicated media bitrate, and derived estimates. Each supported measurement SHALL have documented source, bits-per-second units, time window, and update semantics.

#### Scenario: Throughput and bitrate differ
- **WHEN** a source provides both observed throughput and indicated bitrate
- **THEN** consumers can distinguish them and neither is described as total available network capacity.

### Requirement: Samples respect item lifetime
Telemetry SHALL attribute samples to the active item/session, avoid duplicate cumulative accounting, handle resets without negative rates, and stop observation on detach.

#### Scenario: Counter reset or item replacement
- **WHEN** a counter resets or the host replaces the current item
- **THEN** a new baseline is established and old-item samples cannot affect the new session.

### Requirement: Missing source data remains unavailable
Telemetry SHALL omit unsupported measurements or explicitly identify them as unavailable rather than synthesize zero throughput.

#### Scenario: Local media has no access-log throughput
- **WHEN** the source provides no transfer measurements
- **THEN** bandwidth remains unavailable and playback continues normally.

### Requirement: Dual-EWMA estimator and native comparison
Bandwidth diagnostics SHALL provide instantaneous, fast, slow and driving estimates plus confidence equivalent to Android for the same valid sample sequence. A native comparison SHALL be identified separately and SHALL NOT be inferred from advertised media bitrate.

#### Scenario: Shared estimator vectors
- **WHEN** Android and iOS receive the same inputs including startup samples and a throughput drop
- **THEN** estimates and confidence match within the fixture tolerance and reset behavior is equivalent.

### Requirement: Estimator-driven adaptation
The SDK SHALL provide an opt-in host integration that demonstrably influences adaptive bitrate selection with the custom estimate while preserving host player ownership.

#### Scenario: Custom estimate changes under a controlled network profile
- **WHEN** the host opts in and playback runs on a multi-variant stream
- **THEN** a trace demonstrates the relationship between the estimator, native control input and selected variant.
