# Spec Delta

## Purpose
Define reliable iOS playback diagnostics while preserving application ownership of playback and explicit measurement limitations.

## ADDED Requirements

### Requirement: Attachment preserves host ownership
Diagnostics SHALL remove their observations on detach without changing playback, the current item, audio-session policy, or the shared event pipeline. Repeated detach SHALL be safe.

#### Scenario: Detach during playback
- **WHEN** an application detaches diagnostics twice while playing
- **THEN** playback continues with the same item and shared pipeline, and diagnostic observations are removed.

### Requirement: Sessions follow item lifecycle
Diagnostics SHALL associate events with the active item/session, terminate sessions on replacement, removal, completion or fatal failure, and reject stale-item callbacks. Pausing SHALL NOT end a session.

#### Scenario: Item replacement
- **WHEN** the host replaces an item and an old callback arrives afterward
- **THEN** the old session ends with replacement, the new item has a distinct session, and the stale callback cannot modify it.

#### Scenario: Replay
- **WHEN** the host explicitly starts another diagnostic session for a completed item
- **THEN** replay uses a fresh session and counters do not include the previous playback.

### Requirement: Timing reflects measurement provenance
First-frame timing SHALL require a valid host rendering or identified display-readiness signal. Readiness SHALL be distinguished from rendering. Unavailable timing SHALL remain unknown, and explicitly tracked seeks and startup waits SHALL be excluded from rebuffer accounting.

#### Scenario: No frame signal
- **WHEN** playback starts without a valid first-frame signal
- **THEN** first-frame timing and dependent rebuffer summaries remain unavailable.

#### Scenario: Tracked seek
- **WHEN** a tracked seek causes waiting before completion
- **THEN** that wait does not increment rebuffer counts.

### Requirement: Delivery loss remains visible
Accepted adapter events SHALL retain publication order. Overflow SHALL report diagnostic failure without interrupting playback, and affected sessions SHALL be identifiable as incomplete in presentation and export.

#### Scenario: Queue overflow
- **WHEN** diagnostic delivery exceeds its configured capacity
- **THEN** accepted events drain in order, loss is reported, and the session cannot be represented as a complete measurement.

### Requirement: Exports preserve compatibility and completeness
Session exports SHALL encode schema v3, decode supported v2/v3 inputs, retain unavailable and truncated states, reject invalid values, and distinguish delivery incompleteness from retained-history truncation.

#### Scenario: Older session input
- **WHEN** a valid v2 session is decoded
- **THEN** its supported fields retain their meaning without inventing v3-only observations.

### Requirement: Dropped frames use available counters
Dropped-frame measurements SHALL use counter deltas without duplicate counting. Missing or negative source counters SHALL remain unavailable.

#### Scenario: Repeated access-log read
- **WHEN** the same cumulative dropped-frame counter is sampled twice
- **THEN** the second sample adds no duplicate frames.

### Requirement: Android adapter event coverage
The iOS adapter SHALL provide equivalent observable events for available and selected formats, track switches, load failures and decoder initialization. Each event SHALL preserve its session, source and semantics. Unverified iOS equivalents SHALL remain open parity gaps.

#### Scenario: Controlled stream changes variant and one load fails
- **WHEN** the fixture triggers an observed format switch and a resource load failure
- **THEN** the events identify the active session and preserve supported switch and load-failure details.

### Requirement: Cross-platform export interoperability
Android and iOS SHALL exchange the common diagnostic event and session data through a verified shared schema or explicit compatibility mode. An export that cannot preserve platform-specific information SHALL disclose that limitation.

#### Scenario: Exchange real exports
- **WHEN** actual Android and iOS exports are opened by the other platform's reader
- **THEN** the common fields, events and summary inputs retain their meaning and incompatible data is explicitly reported.
