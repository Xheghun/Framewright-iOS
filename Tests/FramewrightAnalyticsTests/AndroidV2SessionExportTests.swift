import Foundation
import FramewrightAnalytics
import Testing

@Test func androidV2ExportDisclosesLossWithoutInventingFirstFrame() throws {
    func event(_ id: String, _ payload: DiagnosticPayload) throws -> DiagnosticEvent {
        DiagnosticEvent(
            metadata: try DiagnosticEventMetadata(
                sessionId: "s", eventId: id, timestampMs: 42, elapsedRealtimeMs: 43), payload: payload)
    }
    let events = try [
        event("start", .sessionStart(SessionStartPayload(mediaUri: "<redacted>", deviceName: "Test Device"))),
        event(
            "ready", .renderFirstFrame(RenderFirstFramePayload(elapsedSincePrepareMs: 100, source: .readyForDisplay))),
        event("play", .playbackStateChanged(PlaybackStateChangedPayload(status: .playing))),
        event("jump", .positionDiscontinuity(PositionDiscontinuityPayload(positionMs: 200))),
        event("end", .sessionEnd(SessionEndPayload(durationMs: 300, reason: .playbackEnded))),
    ]
    let snapshot = try SessionSnapshot(sessionId: "s", truncated: true, deliveryIncomplete: true, events: events)
    let codec = DiagnosticEventJSONCodec()
    let export = try codec.exportAndroidV2(snapshot)
    #expect(
        export.omissions == [
            .deliveryCompleteness, .deviceName(eventID: "start"), .displayReadiness(eventID: "ready"),
            .unsupportedEvent(eventID: "play", type: .playbackStateChanged),
            .unsupportedEvent(eventID: "jump", type: .positionDiscontinuity),
        ])
    let wire = try #require(
        JSONSerialization.jsonObject(with: Data(export.json.utf8)) as? [String: Any])
    #expect(wire["schemaVersion"] as? Int == 2)
    #expect(wire["deliveryIncomplete"] == nil)
    let restored = try codec.decodeSession(export.json)
    #expect(restored.truncated)
    #expect(restored.events.map(\.eventId) == ["start", "end"])
    #expect(try SessionSummaryCalculator().calculate(restored).timeToFirstFrameMs == nil)
    #expect(try codec.decodeSession(codec.encodeSession(snapshot)) == snapshot)
}

@Test func pinnedAndroidCodecExportRetainsCommonFieldsAndSummary() throws {
    let fixture = try #require(Bundle.module.url(forResource: "android-v0.1.1-session", withExtension: "json"))
    let codec = DiagnosticEventJSONCodec()
    let session = try codec.decodeSession(String(contentsOf: fixture, encoding: .utf8))
    #expect(session.sessionId == "android")
    #expect(session.events.map(\.eventId) == ["start", "frame", "end"])
    #expect(try SessionSummaryCalculator().calculate(session).timeToFirstFrameMs == 100)
    let compatible = try codec.exportAndroidV2(session)
    #expect(compatible.omissions.isEmpty)
    #expect(try codec.decodeSession(compatible.json) == session)
}
