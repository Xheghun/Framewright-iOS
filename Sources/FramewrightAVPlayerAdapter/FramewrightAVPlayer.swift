@preconcurrency import AVFoundation
import Foundation
import FramewrightAnalytics

public struct AVPlayerSeekToken: Sendable, Equatable {
    fileprivate let id: UUID
}

// KVO transfers item references; their properties are only read on the main actor.
private struct ObservedItem: @unchecked Sendable {
    let item: AVPlayerItem?
}

@MainActor
public final class FramewrightAVPlayer: PlayerEventSource {
    private let player: AVPlayer
    private let configuration: AVPlayerDiagnosticsConfiguration
    private let playerObservations = ObservationLifetime()
    private let itemObservations = ObservationLifetime()
    private var attachmentID: UUID?
    private var itemID: UUID?
    private var observedItem: AVPlayerItem?
    private weak var preparedItem: AVPlayerItem?
    private var preparedAt: Int64?
    private var nextSessionID: String?
    private var seekToken: AVPlayerSeekToken?
    private var state = PlaybackSessionState()
    private var writer: OrderedEventWriter?

    public var isAttached: Bool { attachmentID != nil }
    public var activeSessionID: String? { state.sessionID }
    public var playerState: PlayerState { state.playerState }

    public init(player: AVPlayer, configuration: AVPlayerDiagnosticsConfiguration = .init()) {
        self.player = player
        self.configuration = configuration
    }

    public static func attach(
        player: AVPlayer, pipeline: DiagnosticEventPipeline,
        sessionId: String = UUID().uuidString,
        configuration: AVPlayerDiagnosticsConfiguration = .init()
    ) throws -> FramewrightAVPlayer {
        let source = FramewrightAVPlayer(player: player, configuration: configuration)
        try source.attach(pipeline: pipeline, sessionId: sessionId)
        return source
    }

    public func attach(pipeline: DiagnosticEventPipeline, sessionId: String) throws {
        guard !isAttached else { throw AVPlayerDiagnosticsError.alreadyAttached }
        try validate(sessionId)
        if let writer, writer.hasOverflowed {
            guard writer.isDrained else { throw AVPlayerDiagnosticsError.deliveryPending }
            self.writer = nil
        }
        if let writer {
            try writer.setPipeline(pipeline)
        } else {
            writer = OrderedEventWriter(pipeline: pipeline, onError: configuration.onDiagnosticsError)
        }
        let attachment = UUID()
        attachmentID = attachment
        nextSessionID = sessionId
        playerObservations.add(
            player.observe(\.currentItem, options: [.new]) { [weak self] _, change in
                let reference = ObservedItem(item: change.newValue ?? nil)
                deliverOnMain { [weak self] in
                    guard let self, self.attachmentID == attachment else { return }
                    self.replaceItem(reference.item)
                }
            })
        playerObservations.add(
            player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
                deliverOnMain { [weak self] in self?.synchronizePlayback(attachment: attachment) }
            })
        playerObservations.add(
            player.observe(\.reasonForWaitingToPlay, options: [.new]) { [weak self] _, _ in
                deliverOnMain { [weak self] in self?.synchronizePlayback(attachment: attachment) }
            })
        playerObservations.add(
            player.observe(\.status, options: [.new]) { [weak self] _, _ in
                deliverOnMain { [weak self] in self?.synchronizePlayback(attachment: attachment) }
            })
        replaceItem(player.currentItem)
        synchronizePlayback(attachment: attachment)
    }

    public func detach() {
        guard isAttached else { return }
        attachmentID = nil
        itemID = nil
        playerObservations.cancel()
        itemObservations.cancel()
        process { try $0.end(reason: .released, at: .now) }
        observedItem = nil
        preparedItem = nil
        preparedAt = nil
        nextSessionID = nil
        seekToken = nil
    }

    /// Waits for events already accepted by the adapter, including a preceding detach.
    public func flush() async {
        guard let writer else { return }
        await writer.flush()
    }

    public func endSession(reason: SessionEndReason = .userStopped) {
        process { try $0.end(reason: reason, at: .now) }
        seekToken = nil
    }

    /// Starts another diagnostic session for the current item, for example before replay.
    public func startSession(sessionId: String = UUID().uuidString) throws {
        guard isAttached else { throw AVPlayerDiagnosticsError.notAttached }
        try validate(sessionId)
        guard let item = observedItem, player.currentItem === item else { throw AVPlayerDiagnosticsError.noCurrentItem }
        seekToken = nil
        let payload = try sessionPayload(for: item)
        writer?.write(try state.start(id: sessionId, payload: payload, preparedMs: nil, at: .now))
        observeItem(item)
        if let attachmentID { synchronizePlayback(attachment: attachmentID) }
    }

    /// Call before the host begins preparing or assigning this item.
    public func recordPreparationStarted(for item: AVPlayerItem) throws {
        guard isAttached else { throw AVPlayerDiagnosticsError.notAttached }
        let now = DiagnosticTime.now
        if observedItem === item {
            state.markPreparation(at: now)
        } else {
            preparedItem = item
            preparedAt = now.monotonicMs
        }
    }

    /// Call only from a host rendering signal. Playback readiness alone is insufficient.
    @discardableResult
    public func recordFirstFrame(for item: AVPlayerItem) -> Bool {
        guard isAttached, observedItem === item, player.currentItem === item else { return false }
        do {
            let events = try state.firstFrame(at: .now)
            writer?.write(events)
            return !events.isEmpty
        } catch {
            configuration.onDiagnosticsError(error)
            return false
        }
    }

    public func beginSeek(for item: AVPlayerItem) throws -> AVPlayerSeekToken {
        guard isAttached else { throw AVPlayerDiagnosticsError.notAttached }
        guard state.sessionID != nil, observedItem === item, player.currentItem === item else {
            throw AVPlayerDiagnosticsError.noCurrentItem
        }
        let token = AVPlayerSeekToken(id: UUID())
        seekToken = token
        state.beginSeek()
        return token
    }

    public func endSeek(_ token: AVPlayerSeekToken) {
        guard seekToken == token else { return }
        seekToken = nil
        state.finishSeek()
        if let attachmentID { synchronizePlayback(attachment: attachmentID) }
    }

    private func replaceItem(_ item: AVPlayerItem?) {
        guard observedItem !== item else { return }
        itemObservations.cancel()
        itemID = nil
        process { try $0.end(reason: .replaced, at: .now) }
        observedItem = item
        seekToken = nil
        guard let item else { return }
        let sessionID = nextSessionID ?? UUID().uuidString
        nextSessionID = nil
        let prepared = preparedItem === item ? preparedAt : nil
        if preparedItem === item {
            preparedItem = nil
            preparedAt = nil
        }
        do {
            writer?.write(
                try state.start(id: sessionID, payload: sessionPayload(for: item), preparedMs: prepared, at: .now))
        } catch { configuration.onDiagnosticsError(error) }
        observeItem(item)
        if let attachmentID { synchronizePlayback(attachment: attachmentID) }
    }

    private func observeItem(_ item: AVPlayerItem) {
        itemObservations.cancel()
        let token = UUID()
        itemID = token
        itemObservations.add(
            item.observe(\.status, options: [.new]) { [weak self] _, _ in
                deliverOnMain { [weak self] in
                    guard let self, self.itemID == token, let attachment = self.attachmentID else { return }
                    self.synchronizePlayback(attachment: attachment)
                }
            })
        observe(AVPlayerItem.didPlayToEndTimeNotification, item: item, token: token) { source, _ in
            source.process { try $0.end(reason: .playbackEnded, at: .now) }
        }
        let jumpToken = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.timeJumpedNotification, object: item, queue: nil
        ) { [weak self] notification in
            guard let item = notification.object as? AVPlayerItem else { return }
            let seconds = item.currentTime().seconds
            guard seconds.isFinite, seconds >= 0 else { return }
            let position = DiagnosticTime.milliseconds(seconds)
            let time = DiagnosticTime.now
            deliverOnMain { [weak self] in
                guard let self, self.itemID == token, self.isAttached else { return }
                self.process { try $0.positionJumped(to: position, at: time) }
            }
        }
        itemObservations.addNotification(jumpToken)
        let failureToken = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: nil
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
            let code = error.map { "\($0.domain):\($0.code)" } ?? "AVPlayerItem.failedToPlayToEnd"
            let message = error?.localizedDescription
            deliverOnMain { [weak self] in
                guard let self, self.itemID == token, self.isAttached else { return }
                self.fail(code: code, message: message)
            }
        }
        itemObservations.addNotification(failureToken)
    }

    private func observe(
        _ name: Notification.Name, item: AVPlayerItem, token: UUID,
        handler: @escaping @MainActor @Sendable (FramewrightAVPlayer, UUID) -> Void
    ) {
        let observation = NotificationCenter.default.addObserver(forName: name, object: item, queue: nil) {
            [weak self] _ in
            deliverOnMain { [weak self] in
                guard let self, self.itemID == token, self.isAttached else { return }
                handler(self, token)
            }
        }
        itemObservations.addNotification(observation)
    }

    private func synchronizePlayback(attachment: UUID) {
        guard attachmentID == attachment, let item = observedItem, player.currentItem === item else { return }
        if item.status == .failed || player.status == .failed {
            let error = (item.error ?? player.error) as NSError?
            fail(
                code: error.map { "\($0.domain):\($0.code)" } ?? "AVPlayer.failed", message: error?.localizedDescription
            )
            return
        }
        let control: PlaybackControl
        switch player.timeControlStatus {
        case .paused: control = .paused
        case .waitingToPlayAtSpecifiedRate: control = .waiting
        case .playing: control = .playing
        @unknown default: return
        }
        let reason = player.reasonForWaitingToPlay
        let buffering = reason == .toMinimizeStalls || reason == .evaluatingBufferingRate
        let buffered = Self.bufferedDurationMs(
            position: item.currentTime(), ranges: item.loadedTimeRanges.map(\.timeRangeValue))
        process {
            try $0.update(
                control: control, ready: item.status == .readyToPlay,
                buffering: buffering, bufferedMs: buffered, at: .now)
        }
    }

    private func fail(code: String, message: String?) {
        let message = configuration.includeErrorMessages ? message : nil
        process { try $0.fail(code: code, message: message, at: .now) }
    }

    private func sessionPayload(for item: AVPlayerItem) throws -> SessionStartPayload {
        let uri = (item.asset as? AVURLAsset)?.url.absoluteString ?? "<unknown>"
        return try SessionStartPayload(
            mediaUri: configuration.sanitizeURI(uri),
            deviceModel: configuration.deviceModel, osVersion: configuration.osVersion,
            appVersion: configuration.appVersion, deviceName: configuration.deviceName)
    }

    private func process(_ operation: (inout PlaybackSessionState) throws -> [DiagnosticEvent]) {
        do { writer?.write(try operation(&state)) } catch { configuration.onDiagnosticsError(error) }
    }

    private func validate(_ id: String) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AVPlayerDiagnosticsError.invalidSessionID
        }
    }

    static func bufferedDurationMs(position: CMTime, ranges: [CMTimeRange]) -> Int64 {
        let current = position.seconds
        guard current.isFinite else { return 0 }
        var end = current
        for range in ranges.sorted(by: { $0.start.seconds < $1.start.seconds }) {
            let start = range.start.seconds
            let rangeEnd = CMTimeRangeGetEnd(range).seconds
            guard start.isFinite, rangeEnd.isFinite, rangeEnd >= start else { continue }
            if start <= end, rangeEnd > end { end = rangeEnd }
        }
        return DiagnosticTime.milliseconds(end - current)
    }

    deinit {
        playerObservations.cancel()
        itemObservations.cancel()
        do { writer?.write(try state.end(reason: .released, at: .now)) } catch {
            let handler = configuration.onDiagnosticsError
            Task { @MainActor in handler(error) }
        }
        writer?.finish()
    }
}
