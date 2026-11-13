# Spec Delta

## Purpose
Expose source-supported media format and codec information without claiming unobserved decoder behavior or platform capability parity.

## ADDED Requirements

### Requirement: Format reports identify their scope
Inspection SHALL distinguish asset or track metadata, active playback format, and independently established device capabilities. Reported codec, dimensions, frame rate and color/HDR values SHALL identify their measurement scope.

#### Scenario: Alternative tracks exist
- **WHEN** an asset exposes multiple formats but only one is selected
- **THEN** available-format metadata cannot be mistaken for the active playback format.

### Requirement: Unobservable decoder details remain unavailable
Inspection SHALL NOT infer decoder identity, initialization duration, hardware acceleration or capability ranges from metadata alone.

#### Scenario: Decoder identity is unobservable
- **WHEN** the platform source establishes codec metadata but no decoder identity
- **THEN** codec metadata is available and decoder identity remains unavailable.

### Requirement: Inspection is isolated from playback
Inspection failure SHALL report unavailable or failed inspection without changing host playback, and a stale result SHALL NOT replace the current item's inspection state.

#### Scenario: Unsupported asset during replacement
- **WHEN** inspection fails after the inspected item was replaced
- **THEN** playback continues and the result does not overwrite the new item's state.

### Requirement: Decoder catalog and selected-decoder reporting
The SDK SHALL provide an on-demand device decoder catalog and selected-decoder reporting equivalent to the Android baseline. Decoder identity, initialization duration, implementation class, profiles, format support and capability fields require independent evidence; unsupported fields SHALL remain tracked gaps.

#### Scenario: Selected format is inspected on hardware
- **WHEN** a supported fixture plays on a test device
- **THEN** selected-decoder details and catalog entries are independently sourced, and codec-only metadata is not presented as decoder evidence.
