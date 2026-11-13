import AVFoundation
import Foundation

@main @MainActor
struct PlaybackProbe {
    static func main() async {
        let url = URL(string: CommandLine.arguments[1])!
        let expectFailure = CommandLine.arguments.contains("--failure")
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.play()
        let deadline = ContinuousClock.now.advanced(by: .seconds(25))
        while ContinuousClock.now < deadline {
            if item.status == .failed || player.status == .failed {
                print("failure: \(String(describing: item.error ?? player.error))")
                exit(expectFailure ? 0 : 1)
            }
            let seconds = player.currentTime().seconds
            if !expectFailure && seconds.isFinite && seconds >= 2 {
                let rates = item.accessLog()?.events.map(\.indicatedBitrate) ?? []
                print("playback: \(seconds)s; indicated bitrates: \(rates)")
                exit(0)
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        print("timed out waiting for \(expectFailure ? "failure" : "playback")")
        exit(1)
    }
}
