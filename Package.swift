// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Framewright",
    platforms: [.iOS(.v16), .macOS(.v13)],
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
        .testTarget(
            name: "FramewrightAnalyticsTests", dependencies: ["FramewrightAnalytics"], resources: [.process("Fixtures")]
        ),
        .target(name: "FramewrightAVPlayerAdapter", dependencies: ["FramewrightAnalytics"]),
        .testTarget(name: "FramewrightAVPlayerAdapterTests", dependencies: ["FramewrightAVPlayerAdapter"]),
        .target(name: "FramewrightBandwidthMonitor", dependencies: ["FramewrightAnalytics"]),
        .testTarget(
            name: "FramewrightBandwidthMonitorTests",
            dependencies: ["FramewrightBandwidthMonitor"], resources: [.process("Fixtures")]
        ),
        .target(name: "FramewrightCodecInspector", dependencies: ["FramewrightAnalytics"]),
        .testTarget(
            name: "FramewrightCodecInspectorTests", dependencies: ["FramewrightCodecInspector"],
            resources: [.process("Fixtures")]
        ),
        .target(name: "FramewrightDRMInspector", dependencies: ["FramewrightAnalytics"]),
        .testTarget(name: "FramewrightDRMInspectorTests", dependencies: ["FramewrightDRMInspector"]),
        .target(name: "FramewrightDiagnosticsOverlay", dependencies: ["FramewrightAnalytics"]),
        .testTarget(name: "FramewrightDiagnosticsOverlayTests", dependencies: ["FramewrightDiagnosticsOverlay"]),
        .target(name: "FramewrightStorage", dependencies: ["FramewrightAnalytics"]),
        .testTarget(name: "FramewrightStorageTests", dependencies: ["FramewrightStorage"]),
    ]
)
