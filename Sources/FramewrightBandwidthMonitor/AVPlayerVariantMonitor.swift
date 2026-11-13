@preconcurrency import AVFoundation
import Foundation

public struct ObservedVariantSwitch: Equatable, Sendable {
    public let previousPeakBitrateBps: Double?
    public let selectedPeakBitrateBps: Double?
    public let mediaTimeSeconds: Double?
}

/// Reports successful HLS switches from AVFoundation. It does not infer the switch's cause.
@available(iOS 18, macOS 15, *)
@MainActor
public final class AVPlayerVariantMonitor {
    private var observation: Task<Void, Never>?

    public init() {}

    public func observe(
        _ item: AVPlayerItem, onSwitch: @escaping @MainActor @Sendable (ObservedVariantSwitch) -> Void
    ) {
        detach()
        observation = Task { [weak item] in
            guard let item else { return }
            do {
                for try await event in item.metrics(forType: AVMetricPlayerItemVariantSwitchEvent.self) {
                    guard !Task.isCancelled else { return }
                    guard event.didSucceed else { continue }
                    let seconds = event.mediaTime.seconds
                    onSwitch(
                        ObservedVariantSwitch(
                            previousPeakBitrateBps: Self.rate(event.fromVariant?.peakBitRate),
                            selectedPeakBitrateBps: Self.rate(event.toVariant.peakBitRate),
                            mediaTimeSeconds: seconds.isFinite && seconds >= 0 ? seconds : nil))
                }
            } catch {
                // Cancellation or an unavailable metric stream supplies no switch evidence.
            }
        }
    }

    public func detach() {
        observation?.cancel()
        observation = nil
    }

    deinit { observation?.cancel() }

    private static func rate(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }
}
