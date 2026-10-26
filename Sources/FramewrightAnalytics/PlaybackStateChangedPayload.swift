import Foundation

public enum PlaybackStatus: String, Codable, Equatable, Sendable {
    case paused = "PAUSED"
    case waiting = "WAITING"
    case playing = "PLAYING"
}

public struct PlaybackStateChangedPayload: Codable, Equatable, Sendable {
    public let status: PlaybackStatus

    public init(status: PlaybackStatus) {
        self.status = status
    }
}
