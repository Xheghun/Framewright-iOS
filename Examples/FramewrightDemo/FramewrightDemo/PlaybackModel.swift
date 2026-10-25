@preconcurrency import AVFoundation
import Combine
import Foundation
import FramewrightAVPlayerAdapter
import FramewrightAnalytics

@MainActor
final class PlaybackModel: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var connected = false
    @Published private(set) var events: [DiagnosticEvent] = []
    @Published private(set) var sessions: [String] = []
    @Published var selectedSession = ""
    @Published var message: String?
    @Published private(set) var playbackStatus = "Paused"
    @Published private(set) var position = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var isSeeking = false
    @Published private(set) var diagnosticsIncomplete = false
    private var lifecycleBusy = false
    private var seekID: UUID?
    private var pipeline: DiagnosticEventPipeline?
    private var diagnostics: FramewrightAVPlayer?
    private var subscription: DiagnosticSubscription?
    private var eventTask: Task<Void, Never>?

    func connect() async {
        while lifecycleBusy { await Task.yield() }
        guard !connected, !Task.isCancelled else { return }
        lifecycleBusy = true
        defer { lifecycleBusy = false }
        do {
            let pipeline =
                try self.pipeline ?? DiagnosticEventPipeline(maxEventsPerSession: 500, liveBufferCapacity: 256)
            self.pipeline = pipeline
            let subscription = await pipeline.subscribe()
            self.subscription = subscription
            let configuration = AVPlayerDiagnosticsConfiguration(onDiagnosticsError: { [weak self] error in
                self?.diagnosticsIncomplete = true
                self?.message = "Diagnostics interrupted: \(error)"
            })
            diagnostics = try FramewrightAVPlayer.attach(
                player: player, pipeline: pipeline, configuration: configuration)
            eventTask = Task { [weak self] in
                for await event in subscription.events {
                    guard !Task.isCancelled else { break }
                    await self?.receive(event, pipeline: pipeline)
                }
            }
            connected = true
        } catch { message = String(describing: error) }
    }

    func disconnect() async {
        while lifecycleBusy { await Task.yield() }
        lifecycleBusy = true
        defer { lifecycleBusy = false }
        connected = false
        seekID = nil
        isSeeking = false
        player.pause()
        player.currentItem?.cancelPendingSeeks()
        diagnostics?.detach()
        await diagnostics?.flush()
        if let pipeline, let subscription { await pipeline.unsubscribe(subscription.id) }
        await eventTask?.value
        eventTask = nil
        diagnostics = nil
        subscription = nil
        player.replaceCurrentItem(with: nil)
        // Preserve the pipeline for export while the view is off screen.
    }

    func load(_ url: URL, autoplay: Bool = false) {
        guard connected, let diagnostics else { return }
        player.pause()
        player.currentItem?.cancelPendingSeeks()
        isSeeking = false
        seekID = nil
        let item = AVPlayerItem(url: url)
        do {
            try diagnostics.recordPreparationStarted(for: item)
            player.replaceCurrentItem(with: item)
            if let id = diagnostics.activeSessionID { selectedSession = id }
            message = nil
            if autoplay { player.play() }
            refresh()
        } catch { message = String(describing: error) }
    }

    static func streamURL(_ text: String) -> URL? {
        guard let parts = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
            parts.scheme?.lowercased() == "https", parts.host?.isEmpty == false,
            parts.user == nil, parts.password == nil
        else { return nil }
        return parts.url
    }

    func loadStream(_ text: String) {
        guard let url = Self.streamURL(text) else {
            message = "Enter an HTTPS media URL without embedded credentials."
            return
        }
        load(url)
    }

    func play() {
        guard connected, player.currentItem != nil else { return }
        if diagnostics?.activeSessionID == nil {
            replay()
            return
        }
        player.play()
        refresh()
    }

    func pause() {
        seekID = nil
        isSeeking = false
        player.currentItem?.cancelPendingSeeks()
        player.pause()
        refresh()
    }

    func replay() {
        guard connected, let diagnostics, player.currentItem?.status == .readyToPlay else { return }
        do {
            player.pause()
            try diagnostics.startSession()
            selectedSession = diagnostics.activeSessionID ?? ""
            if let item = player.currentItem { try diagnostics.recordPreparationStarted(for: item) }
            seek(to: 0, playAfter: true)
        } catch { message = String(describing: error) }
    }

    func seek(by offset: Double) { seek(to: position + offset) }

    private func seek(to seconds: Double, playAfter: Bool = false) {
        guard connected, let diagnostics, let item = player.currentItem,
            item.status == .readyToPlay, seconds.isFinite
        else { return }
        do {
            let token = try diagnostics.beginSeek(for: item)
            isSeeking = true
            let requestID = UUID()
            seekID = requestID
            let target = max(0, duration > 0 ? min(seconds, duration) : seconds)
            player.seek(to: CMTime(seconds: target, preferredTimescale: 600)) {
                [weak self, weak diagnostics] finished in
                Task { @MainActor in
                    diagnostics?.endSeek(token)
                    guard let self, self.player.currentItem === item, self.seekID == requestID else { return }
                    self.seekID = nil
                    self.isSeeking = false
                    if finished, playAfter, self.connected { self.player.play() }
                    self.refresh()
                }
            }
        } catch { message = String(describing: error) }
    }

    func refresh() {
        let current = player.currentTime().seconds
        position = current.isFinite ? max(0, current) : 0
        let length = player.currentItem?.duration.seconds ?? 0
        duration = length.isFinite ? max(0, length) : 0
        if player.currentItem?.status == .failed {
            playbackStatus = "Playback failed"
        } else if diagnostics?.playerState == .ended {
            playbackStatus = "Ended"
        } else {
            switch player.timeControlStatus {
            case .playing: playbackStatus = "Playing"
            case .waitingToPlayAtSpecifiedRate: playbackStatus = "Waiting"
            case .paused: playbackStatus = "Paused"
            @unknown default: playbackStatus = "Unknown"
            }
        }
    }

    func exportSession(_ id: String) async throws -> String {
        guard let pipeline, !id.isEmpty else { throw ExportError.noSession }
        await diagnostics?.flush()
        return try await pipeline.exportSessionJSON(sessionId: id)
    }

    private func receive(_ event: DiagnosticEvent, pipeline: DiagnosticEventPipeline) async {
        if !sessions.contains(event.sessionId) {
            sessions.append(event.sessionId)
            if selectedSession.isEmpty { selectedSession = event.sessionId }
        }
        events.append(event)
        if events.count > 200 { events.removeFirst(events.count - 200) }
        while sessions.count > 10 {
            let removed = sessions.removeFirst()
            events.removeAll { $0.sessionId == removed }
            if selectedSession == removed { selectedSession = sessions.last ?? "" }
            await pipeline.clear(sessionId: removed)
        }
        if case .playbackError(let error) = event.payload { message = "Playback failed: \(error.errorCode)" }
        refresh()
    }

    enum ExportError: Error { case noSession }
    deinit { eventTask?.cancel() }
}
