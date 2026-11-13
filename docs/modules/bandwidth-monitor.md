# Bandwidth monitor

Use the `FramewrightBandwidthMonitor` product. Its pure Swift dual-EWMA estimator uses the same
defaults, sample math, startup threshold and session confidence as Android v0.1.1. Feed qualifying
network bytes and transfer duration in milliseconds; the published rates are bits per second.
`beginSession()` resets confidence and retains the meter history; `reset()` starts a new meter.

```swift
import FramewrightBandwidthMonitor

let bandwidth = AVPlayerBandwidthMonitor(configuration: try BandwidthEstimatorConfiguration())
bandwidth.attach(to: item)
let samples = bandwidth.sample(for: item)
bandwidth.detach()
```

In a main-actor host, sample on the active item's access-log notifications. The sampler baselines
existing counters on attachment, rejects callbacks for replaced items and produces no samples for
local files. It separates Apple's observed throughput from the server's indicated media bitrate.
A derived estimate uses positive deltas of cumulative bytes and active transfer time, not per-segment
network transactions; unavailable observations stay absent. The sampler does not emit Android's
`BANDWIDTH_SAMPLE` payload with a fabricated default estimate, or modify player bitrate policy.

For HLS on iOS 18+, see [AVMetrics](https://developer.apple.com/videos/play/wwdc2024/10113/) for the
per-resource investigation. Access-log counters and the portable estimator are available across the
package's deployment range; native ABR comparison and estimator-driven selection need separate evidence.

A host can explicitly apply a custom estimate using `AVPlayerBandwidthPreference`. It sets
`preferredPeakBitRate`, respects a stricter host limit, and restores the prior preference on
`detach()` or replacement unless the host has overridden the value. Call `detach()` when the
host stops using the policy. This is a bitrate preference; it neither chooses a rendition nor
proves Android's estimator-driven variant selection.

On iOS 18 and later, `AVPlayerVariantMonitor` can observe successful HLS variant switches
reported by AVMetrics for the active item. Detach it when the host replaces the item.
Switch observations report the selected variant's declared peak bitrate when available.
The native ABR estimate and decision reason remain unavailable.
