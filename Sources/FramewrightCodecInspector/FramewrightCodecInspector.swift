@preconcurrency import AVFoundation
import Foundation
import VideoToolbox

/// Metadata for an asset's video format, not the decoder currently selected by AVPlayer.
public struct VideoFormatInspection: Equatable, Sendable {
    public let codecType: FourCharCode
    public let width: Int32
    public let height: Int32
    public let nominalFramesPerSecond: Float?
    public let hardwareDecodeSupportedForCodec: Bool
}

public struct FramewrightCodecInspector: Sendable {
    public init() {}

    /// Reports asset-track formats.
    @MainActor
    public func inspectVideoFormats(in asset: AVAsset) async throws -> [VideoFormatInspection] {
        var output: [VideoFormatInspection] = []
        for track in try await asset.loadTracks(withMediaType: .video) {
            let fps = try await track.load(.nominalFrameRate)
            for format in try await track.load(.formatDescriptions) {
                let codec = CMFormatDescriptionGetMediaSubType(format)
                let dimensions = CMVideoFormatDescriptionGetDimensions(format)
                output.append(
                    VideoFormatInspection(
                        codecType: codec, width: dimensions.width, height: dimensions.height,
                        nominalFramesPerSecond: fps.isFinite && fps > 0 ? fps : nil,
                        hardwareDecodeSupportedForCodec: VTIsHardwareDecodeSupported(codec)))
            }
        }
        return output
    }
}

/// A declared HLS variant, independent of whether the player selected it.
public struct HLSVariantInspection: Equatable, Sendable {
    public let peakBitrateBps: Double?
    public let averageBitrateBps: Double?
    public let width: Double?
    public let height: Double?
}

extension FramewrightCodecInspector {
    @MainActor
    public func inspectHLSVariants(in asset: AVURLAsset) async throws -> [HLSVariantInspection] {
        try await asset.load(.variants).map { variant in
            HLSVariantInspection(
                peakBitrateBps: Self.knownPositive(variant.peakBitRate),
                averageBitrateBps: Self.knownPositive(variant.averageBitRate),
                width: variant.videoAttributes.flatMap { Self.knownPositive($0.presentationSize.width) },
                height: variant.videoAttributes.flatMap { Self.knownPositive($0.presentationSize.height) })
        }
    }

    private static func knownPositive(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }
}

/// Runs format queries for the host player's current item and drops superseded results.
@MainActor
public final class AVPlayerFormatInspection {
    private weak var player: AVPlayer?
    private var generation = UUID()
    private let inspector = FramewrightCodecInspector()

    public init(player: AVPlayer) { self.player = player }

    public func cancel() { generation = UUID() }

    public func inspectCurrentVideoFormats() async throws -> [VideoFormatInspection]? {
        guard let item = player?.currentItem else { return nil }
        let request = UUID()
        generation = request
        do {
            let formats = try await inspector.inspectVideoFormats(in: item.asset)
            guard generation == request, player?.currentItem === item, !Task.isCancelled else { return nil }
            return formats
        } catch {
            guard generation == request, player?.currentItem === item, !Task.isCancelled else { return nil }
            throw error
        }
    }
}
