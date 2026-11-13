# Spec Delta

## Purpose
Present understandable session diagnostics and portable exports without controlling playback or obscuring unavailable and incomplete measurements.

## ADDED Requirements

### Requirement: Presentation is session-scoped
The UI SHALL display only the selected session and ignore results from cancelled or superseded observations. Dismissing diagnostics SHALL NOT change playback or clear shared history.

#### Scenario: Session selection changes during refresh
- **WHEN** an old refresh completes after the user selects a new session
- **THEN** it does not replace the new session's displayed data.

### Requirement: Measurement limitations are visible
The UI SHALL distinguish unavailable measurements, retained-history truncation, delivery incompleteness and refresh failure. Display-readiness timing SHALL NOT be labeled as confirmed rendering time.

#### Scenario: Incomplete history
- **WHEN** a session has both history truncation and known delivery loss
- **THEN** both limitations remain visible in its details and exported session metadata.

### Requirement: Export matches the selected snapshot
Export SHALL capture the selected session snapshot consistently and expose failures to the user without affecting playback.

#### Scenario: Session updates during export
- **WHEN** newer events arrive after export captures its snapshot
- **THEN** the exported document remains internally consistent and identifies the captured session.

### Requirement: Controls remain accessible
Diagnostic controls and status information SHALL support accessible labels, large Dynamic Type and VoiceOver without making session selection or export inaccessible.

#### Scenario: Large text and screen reader
- **WHEN** the user enables a large accessibility text size and VoiceOver
- **THEN** session selection, completeness information and export controls remain readable and operable.

### Requirement: Overlay and ABR Explorer feature coverage
Presentation SHALL cover the Android overlay's playback, format, decoder, bandwidth, buffer, DRM and issue data. ABR Explorer SHALL display the custom and native comparison timeline, confidence, available and selected bitrates, and switch decisions with their evidence.

#### Scenario: Adaptive stream switches variants
- **WHEN** a diagnostic trace records throughput changes and a verified variant switch
- **THEN** the explorer shows the estimate timeline, track selection and decision, and distinguishes known reasons from inference or missing data.
