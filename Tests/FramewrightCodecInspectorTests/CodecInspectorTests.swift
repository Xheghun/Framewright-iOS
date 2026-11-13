import AVFoundation
import Foundation
import FramewrightCodecInspector
import Testing

@Test @MainActor func readsFixtureFormatWithoutClaimingDecoderIdentity() async throws {
    let url = try #require(Bundle.module.url(forResource: "ColorBars", withExtension: "mp4"))
    let formats = try await FramewrightCodecInspector().inspectVideoFormats(in: AVURLAsset(url: url))
    let format = try #require(formats.first)
    #expect(format.codecType == kCMVideoCodecType_H264)
    #expect(format.width == 640)
    #expect(format.height == 360)
    #expect(format.nominalFramesPerSecond == 24)
}

@Test(
    .enabled(if: ProcessInfo.processInfo.environment["FRAMEWRIGHT_HLS_TEST_URL"] != nil),
    .timeLimit(.minutes(1))
) @MainActor func fixtureDeclaresThreeHLSVariants() async throws {
    let address = try #require(ProcessInfo.processInfo.environment["FRAMEWRIGHT_HLS_TEST_URL"])
    let base = try #require(URL(string: address))
    let variants = try await FramewrightCodecInspector().inspectHLSVariants(
        in: AVURLAsset(url: base.appendingPathComponent("master.m3u8")))
    #expect(variants.compactMap(\.height).sorted() == [180, 360, 540])
    #expect(variants.compactMap(\.peakBitrateBps).sorted() == [476_100, 1_051_100, 2_143_600])
}

@Test @MainActor func invalidMediaDoesNotProduceFormats() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(
        "mp4")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("not video".utf8).write(to: url)
    do {
        let formats = try await FramewrightCodecInspector().inspectVideoFormats(in: AVURLAsset(url: url))
        #expect(formats.isEmpty)
    } catch {
        // AVFoundation may reject the malformed container before producing a track list.
    }
}

@Test @MainActor func inspectionDropsAResultWhenItsItemIsReplaced() async throws {
    let url = try #require(Bundle.module.url(forResource: "ColorBars", withExtension: "mp4"))
    let item = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: item)
    let inspection = AVPlayerFormatInspection(player: player)
    let task = Task { @MainActor in try await inspection.inspectCurrentVideoFormats() }
    await Task.yield()
    player.replaceCurrentItem(with: nil)
    let result = try await task.value
    #expect(result == nil)
    let withoutItem = try await inspection.inspectCurrentVideoFormats()
    #expect(withoutItem == nil)
}
