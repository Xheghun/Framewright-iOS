// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Framewright",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FramewrightAnalytics", targets: ["FramewrightAnalytics"]),
        .library(name: "FramewrightAVPlayerAdapter", targets: ["FramewrightAVPlayerAdapter"]),
        .library(name: "FramewrightBandwidthMonitor", targets: ["FramewrightBandwidthMonitor"]),
        .library(name: "FramewrightCodecInspector", targets: ["FramewrightCodecInspector"]),
        .library(name: "FramewrightDRMInspector", targets: ["FramewrightDRMInspector"]),
        .library(name: "FramewrightDiagnosticsOverlay", targets: ["FramewrightDiagnosticsOverlay"]),
        .library(name: "FramewrightStorage", targets: ["FramewrightStorage"]),
    ],
    targets: [
        .target(name: "FramewrightAnalytics"),
        .target(name: "FramewrightAVPlayerAdapter", dependencies: ["FramewrightAnalytics"]),
        .target(name: "FramewrightBandwidthMonitor", dependencies: ["FramewrightAnalytics"]),
        .target(name: "FramewrightCodecInspector", dependencies: ["FramewrightAnalytics"]),
        .target(name: "FramewrightDRMInspector", dependencies: ["FramewrightAnalytics"]),
        .target(name: "FramewrightDiagnosticsOverlay", dependencies: ["FramewrightAnalytics"]),
        .target(name: "FramewrightStorage", dependencies: ["FramewrightAnalytics"]),
    ]
)
