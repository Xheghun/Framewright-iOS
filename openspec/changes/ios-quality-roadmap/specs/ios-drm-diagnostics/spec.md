# Spec Delta

## Purpose
Provide privacy-preserving FairPlay diagnostic observations while leaving content-key handling and license operations under application control.

## ADDED Requirements

### Requirement: DRM telemetry preserves host ownership
Diagnostics SHALL accept explicitly supplied host observations for request lifecycle, attempt timing, retry and failure without initiating, modifying, or taking ownership of license or content-key operations.

#### Scenario: Host reports a failed attempt
- **WHEN** the host reports a request failure and begins its own retry
- **THEN** diagnostics record the supported observations without initiating another request or changing the retry policy.

### Requirement: DRM output excludes secrets
Diagnostic storage, UI and exports SHALL exclude license request/response bodies, key material, credentials and unsanitized license URLs. Correlation identifiers SHALL be diagnostic identifiers rather than DRM session or content-key identifiers.

#### Scenario: Failure includes sensitive context
- **WHEN** a host observation contains credentials or license-related payload data
- **THEN** only approved sanitized fields reach the diagnostic event stream and exports.

### Requirement: Platform limitations are explicit
Unavailable key status, expiry, security-level and output-protection details SHALL remain unavailable unless a documented public source or explicit supported host observation establishes them.

#### Scenario: Android-only measurement
- **WHEN** no supported iOS observation establishes an Android-equivalent DRM value
- **THEN** no synthetic equivalent is emitted.

### Requirement: Request timing respects lifetimes
Request observations SHALL correlate attempts using diagnostic identifiers, reject invalid or stale session attribution, and distinguish cancellation from completed failure.

#### Scenario: Session ends during a request
- **WHEN** a request callback arrives after its diagnostic session has ended
- **THEN** it cannot be attributed to a replacement session or reported as that session's successful request.

### Requirement: FairPlay diagnostic feature coverage
FairPlay diagnostics SHALL cover equivalent session lifecycle, license and provisioning request observations, key status, expiration, security and current/maximum output-protection information where demonstrated. Each Android capability without a verified equivalent SHALL remain a separate parity gap.

#### Scenario: Protected playback changes key or output state
- **WHEN** authorized hardware playback exposes a validated key or output-protection transition
- **THEN** the diagnostic stream reports the supported transition with provenance and without secrets.
