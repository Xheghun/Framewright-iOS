@preconcurrency import AVFoundation
import Combine
import Foundation
import FramewrightAVPlayerAdapter
import FramewrightAnalytics
import FramewrightBandwidthMonitor
import FramewrightStorage

@MainActor
final class PlaybackModel: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var connected = false
    @Published private(set) var sessions: [String] = []
    @Published var selectedSession = ""
    @Published private(set) var renderingSession = ""
    @Published var message: String?
    @Published private(set) var playbackStatus = "Paused"
    @Published private(set) var position = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var isSeeking = false
    var diagnosticsIncomplete: Bool { isIncomplete(selectedSession) }
    @Published private var failedConnections: Set<UUID> = []
    private var sessionConnections: [String: UUID] = [:]
    private var connectionID = UUID()
    struct BandwidthPoint: Identifiable {
        let id = UUID()
        let elapsed: Double
        let sample: PlaybackBandwidthSample
    }

    @Published private(set) var bandwidthHistory: [BandwidthPoint] = []
    var bandwidthSample: PlaybackBandwidthSample? { bandwidthHistory.last?.sample }
    private var bandwidthStartedAt = ProcessInfo.processInfo.systemUptime
    private var bandwidthMonitor: AVPlayerBandwidthMonitor?
    @Published private(set) var latestVariantSwitch: ObservedVariantSwitch?
    private var stopVariantMonitor: (@MainActor () -> Void)?
    private var lifecycleBusy = false
    private var seekID: UUID?
    @Published private(set) var pipeline: DiagnosticEventPipeline?
    private let persistenceDirectory: URL?
    private var sessionStore: FramewrightSessionStore?
    private var storageSink: PersistentDiagnosticSink?
    @Published private(set) var storedSession: SessionSnapshot?
    private var diagnostics: FramewrightAVPlayer?
    private var subscription: DiagnosticSubscription?
    private var eventTask: Task<Void, Never>?

    init(pipeline: DiagnosticEventPipeline? = nil, persistenceDirectory: URL? = nil) {
        self.pipeline = pipeline
        self.persistenceDirectory = persistenceDirectory
    }

    func openLatestStoredSession() async {
        guard let sessionStore else { return }
        do {
            await diagnostics?.flush()
            try await storageSink?.flush()
            let sessions = try await sessionStore.listSessions()
            var latest: SessionSnapshot?
            var latestTimestamp = Int64.min
            for id in sessions {
                let candidate = try await sessionStore.load(id)
                if let timestamp = candidate.events.last?.metadata.timestampMs, timestamp >= latestTimestamp {
                    latestTimestamp = timestamp
                    latest = candidate
                }
            }
            if let latest {
                storedSession = try latest.mergingDeliveryIncomplete(isIncomplete(latest.sessionId))
            } else {
                message = "No stored diagnostic sessions."
            }
        } catch {
            message = "Unable to read stored diagnostic sessions."
        }
    }

    func dismissStoredSession() { storedSession = nil }

    private func isIncomplete(_ session: String) -> Bool {
        sessionConnections[session].map { failedConnections.contains($0) } ?? false
    }

    func connect() async {
        while lifecycleBusy { await Task.yield() }
        guard !connected, !Task.isCancelled else { return }
        lifecycleBusy = true
        defer { lifecycleBusy = false }
        do {
            if pipeline == nil, let persistenceDirectory {
                do {
                    let store = try FramewrightSessionStore(
                        directory: persistenceDirectory, maximumSessions: 100, maximumBytes: 16_777_216)
                    storageSink = try PersistentDiagnosticSink(store: store)
                    sessionStore = store
                } catch { message = "Session storage unavailable." }
            }
            let sinks: [any DiagnosticEventSink] = storageSink.map { [$0] } ?? []
            let pipeline =
                try self.pipeline
                ?? DiagnosticEventPipeline(maxEventsPerSession: 500, liveBufferCapacity: 256, sinks: sinks)
            self.pipeline = pipeline
            let subscription = await pipeline.subscribe()
            self.subscription = subscription
            let connection = UUID()
            connectionID = connection
            let configuration = AVPlayerDiagnosticsConfiguration(onDiagnosticsError: { [weak self] error in
                self?.failedConnections.insert(connection)
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
            bandwidthMonitor = AVPlayerBandwidthMonitor(configuration: try BandwidthEstimatorConfiguration())
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
        bandwidthMonitor?.detach()
        bandwidthMonitor = nil
        resetBandwidthHistory()
        stopVariants()
        diagnostics?.detach()
        await diagnostics?.flush()
        if let sessionStore, let storageSink {
            do {
                try await storageSink.flush()
                for (id, connection) in sessionConnections where connection == connectionID && isIncomplete(id) {
                    do { try await sessionStore.markDeliveryIncomplete(id) } catch SessionStorageError.notFound {
                        continue
                    }
                }
            } catch { message = "Some diagnostic events could not be stored." }
        }
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
            bandwidthMonitor?.attach(to: item)
            resetBandwidthHistory()
            observeVariants(for: item)
            if let id = diagnostics.activeSessionID {
                sessionConnections[id] = connectionID
                selectedSession = id
                renderingSession = id
            }
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
            sessionConnections[selectedSession] = connectionID
            renderingSession = selectedSession
            if let item = player.currentItem {
                try diagnostics.recordPreparationStarted(for: item)
                bandwidthMonitor?.attach(to: item)
                observeVariants(for: item)
            }
            resetBandwidthHistory()
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

    func firstFrameReady(for item: AVPlayerItem, session: String) {
        guard diagnostics?.activeSessionID == session else { return }
        diagnostics?.recordFirstFrame(for: item, source: .readyForDisplay)
    }

    private func stopVariants() {
        stopVariantMonitor?()
        stopVariantMonitor = nil
        latestVariantSwitch = nil
    }

    private func observeVariants(for item: AVPlayerItem) {
        stopVariants()
        guard #available(iOS 18, *),
            let url = (item.asset as? AVURLAsset)?.url,
            let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
        else { return }
        let monitor = AVPlayerVariantMonitor()
        monitor.observe(item) { [weak self, weak item] observation in
            guard let self, let item, self.player.currentItem === item else { return }
            self.latestVariantSwitch = observation
        }
        stopVariantMonitor = { monitor.detach() }
    }

    private func resetBandwidthHistory() {
        bandwidthHistory = []
        bandwidthStartedAt = ProcessInfo.processInfo.systemUptime
    }

    func refresh() {
        if let item = player.currentItem, let samples = bandwidthMonitor?.sample(for: item), !samples.isEmpty {
            let elapsed = ProcessInfo.processInfo.systemUptime - bandwidthStartedAt
            let points = samples.map { BandwidthPoint(elapsed: elapsed, sample: $0) }
            bandwidthHistory = Array((bandwidthHistory + points).suffix(120))
        }
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
        let snapshot = try await pipeline.snapshot(sessionId: id)
        return try DiagnosticEventJSONCodec().encodeSession(snapshot.mergingDeliveryIncomplete(isIncomplete(id)))
    }

    private func receive(_ event: DiagnosticEvent, pipeline: DiagnosticEventPipeline) async {
        if !sessions.contains(event.sessionId) {
            sessions.append(event.sessionId)
            if selectedSession.isEmpty { selectedSession = event.sessionId }
        }
        while sessions.count > 10 {
            let removed = sessions.removeFirst()
            if selectedSession == removed { selectedSession = sessions.last ?? "" }
            sessionConnections.removeValue(forKey: removed)
            await pipeline.clear(sessionId: removed)
        }
        if case .playbackError(let error) = event.payload { message = "Playback failed: \(error.errorCode)" }
        refresh()
    }

    enum ExportError: Error { case noSession }
    deinit { eventTask?.cancel() }
}
