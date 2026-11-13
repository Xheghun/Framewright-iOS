# Spec Delta

## Purpose
Persist diagnostic sessions for reliable retrieval and export while bounding storage and isolating failures from playback.

## ADDED Requirements

### Requirement: Confirmed writes survive reopening
Storage SHALL expose an explicit durability completion point. A session confirmed durable SHALL remain retrievable after reopening, preserving event order, schema semantics, and completeness flags.

#### Scenario: Reopen after commit
- **WHEN** a session is confirmed durable and storage is reopened
- **THEN** retrieval returns the committed events and completeness metadata.

### Requirement: Failed writes preserve prior committed data
Interrupted writes, corruption and unsupported persisted versions SHALL produce a reported error without falsely confirming durability or modifying playback. A failed replacement write SHALL preserve the previous committed session.

#### Scenario: Interrupted replacement
- **WHEN** writing a replacement session fails before commit
- **THEN** the previous committed session remains retrievable and the failure is reported.

### Requirement: Retention and deletion are explicit
Storage SHALL support configurable session-count and byte limits, deterministic oldest-session eviction, and explicit deletion. It SHALL report retention-related write rejection rather than silently exceed configured limits.

#### Scenario: Retention limit reached
- **WHEN** committing a session would exceed configured limits
- **THEN** eligible oldest sessions are evicted or the write is rejected with an observable reason.

### Requirement: Export is a consistent snapshot
Stored-session export SHALL represent one committed session snapshot and preserve schema version, unavailable fields, truncation, and delivery incompleteness.

#### Scenario: Export during publication
- **WHEN** export runs while newer events are being persisted
- **THEN** the exported document is decodable and internally consistent rather than a mixture of partial commits.

### Requirement: Persisted versions are handled deliberately
Storage SHALL migrate supported historical formats without changing event meaning and reject unsupported versions without destructive overwrite.

#### Scenario: Unsupported version
- **WHEN** a store contains a version newer than the reader supports
- **THEN** the reader reports incompatibility and preserves the original data.

### Requirement: Persistent sink retains accepted event history
The storage sink SHALL persist accepted events in order independently of the bounded analytics cache. Flush and close SHALL report completion or failure, and the host SHALL be able to list, load, export and delete stored sessions.

#### Scenario: Cache evicts older events before storage is reopened
- **WHEN** accepted events are flushed, the in-memory cache evicts older entries, and the store reopens
- **THEN** the stored session retains the committed ordered history independently of the cache.
