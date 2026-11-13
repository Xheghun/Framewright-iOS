import Foundation
import FramewrightAnalytics
import FramewrightStorage
import Testing

private func storageFixture(_ id: String) throws -> SessionSnapshot {
    let metadata = try DiagnosticEventMetadata(sessionId: id, eventId: "ended", timestampMs: 1, elapsedRealtimeMs: 2)
    let end = try SessionEndPayload(durationMs: 2, reason: .released)
    return try SessionSnapshot(
        sessionId: id, truncated: true, deliveryIncomplete: true,
        events: [DiagnosticEvent(metadata: metadata, payload: .sessionEnd(end))])
}

@Test func storeReopensAndExportsTheCommittedSession() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = try storageFixture("../../host-owned")
    let first = try FramewrightSessionStore(directory: directory, maximumSessions: 2, maximumBytes: 16_384)
    try await first.save(original)
    let reopened = try FramewrightSessionStore(directory: directory, maximumSessions: 2, maximumBytes: 16_384)
    #expect(try await reopened.listSessions() == [original.sessionId])
    #expect(try await reopened.load(original.sessionId) == original)
    let json = try await reopened.export(original.sessionId)
    #expect(try DiagnosticEventJSONCodec().decodeSession(json) == original)
    try await reopened.delete(original.sessionId)
    #expect(try await reopened.listSessions().isEmpty)
}

@Test func rejectedWriteKeepsThePreviousCommittedSession() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = try storageFixture("one")
    let store = try FramewrightSessionStore(directory: directory, maximumSessions: 1, maximumBytes: 4_096)
    try await store.save(original)
    let rejected = try storageFixture("two")
    await #expect(throws: SessionStorageError.retentionLimit) { try await store.save(rejected) }
    let large = try storageFixture("one")
    let smaller = try FramewrightSessionStore(directory: directory, maximumSessions: 1, maximumBytes: 1)
    await #expect(throws: SessionStorageError.retentionLimit) { try await smaller.save(large) }
    #expect(try await store.load("one") == original)
}

@Test func persistenceSurvivesAnalyticsEviction() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try FramewrightSessionStore(directory: directory, maximumSessions: 2, maximumBytes: 65_536)
    let sink = try PersistentDiagnosticSink(store: store)
    let pipeline = try DiagnosticEventPipeline(maxEventsPerSession: 1, sinks: [sink])
    for index in 1...3 {
        let metadata = try DiagnosticEventMetadata(
            sessionId: "playback", eventId: "event-\(index)", timestampMs: 1, elapsedRealtimeMs: 2)
        let payload = PlaybackStateChangedPayload(status: index == 2 ? .paused : .playing)
        let result = await pipeline.publish(
            DiagnosticEvent(metadata: metadata, payload: .playbackStateChanged(payload)))
        #expect(result.sinkFailureCount == 0)
    }
    try await sink.close()
    #expect(try await pipeline.snapshot(sessionId: "playback").events.count == 1)
    let reopened = try FramewrightSessionStore(directory: directory, maximumSessions: 2, maximumBytes: 65_536)
    #expect(try await reopened.load("playback").events.map(\.eventId) == ["event-1", "event-2", "event-3"])
}

@Test func unsupportedEnvelopeIsPreservedOnReadAndSave() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let snapshot = try storageFixture("future")
    let store = try FramewrightSessionStore(directory: directory, maximumSessions: 2, maximumBytes: 16_384)
    try await store.save(snapshot)
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    let file = try #require(files.first)
    let future = Data(#"{"version":999,"sessionJSON":"future encoding"}"#.utf8)
    try future.write(to: file)
    await #expect(throws: SessionStorageError.unsupportedStoreVersion(999)) { try await store.load("future") }
    await #expect(throws: SessionStorageError.unsupportedStoreVersion(999)) { try await store.save(snapshot) }
    #expect(try Data(contentsOf: file) == future)
}

@Test func failedDiskCommitDoesNotDiscardPipelineHistory() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try FramewrightSessionStore(directory: directory, maximumSessions: 1, maximumBytes: 1)
    let sink = try PersistentDiagnosticSink(store: store)
    let pipeline = try DiagnosticEventPipeline(sinks: [sink])
    let fixture = try storageFixture("failure")
    let event = try #require(fixture.events.first)
    #expect(await pipeline.publish(event).recorded)
    await #expect(throws: PersistentDiagnosticSinkError.writeFailed) { try await sink.flush() }
    await #expect(throws: PersistentDiagnosticSinkError.writeFailed) { try await sink.close() }
    #expect(throws: PersistentDiagnosticSinkError.closed) { try sink.record(event) }
    #expect(try await pipeline.snapshot(sessionId: "failure").events == [event])
    #expect(try await store.listSessions().isEmpty)
}

@Test func exportDuringAppendReturnsAWholeCommittedPrefix() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try FramewrightSessionStore(directory: directory, maximumSessions: 2, maximumBytes: 65_536)
    let original = try storageFixture("concurrent")
    try await store.save(original)
    let sink = try PersistentDiagnosticSink(store: store)
    for index in 1...8 {
        let metadata = try DiagnosticEventMetadata(
            sessionId: original.sessionId, eventId: "append-\(index)", timestampMs: 1, elapsedRealtimeMs: 2)
        try sink.record(DiagnosticEvent(metadata: metadata, payload: .playbackStateChanged(.init(status: .playing))))
    }
    let expected = ["ended"] + (1...8).map { "append-\($0)" }
    try await withThrowingTaskGroup(of: SessionSnapshot.self) { group in
        for _ in 0..<8 {
            group.addTask {
                let json = try await store.export(original.sessionId)
                return try DiagnosticEventJSONCodec().decodeSession(json)
            }
        }
        for try await snapshot in group {
            #expect(snapshot.events.map(\.eventId) == Array(expected.prefix(snapshot.events.count)))
            #expect(snapshot.truncated && snapshot.deliveryIncomplete == true)
        }
    }
    try await sink.close()
    #expect(try await store.load(original.sessionId).events.map(\.eventId) == expected)
}
