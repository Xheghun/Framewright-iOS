# Stage 0 baseline evidence — 2026-11-13

Android acceptance reference: [Framewright v0.1.1](https://github.com/Xheghun/Framewright/releases/tag/v0.1.1), commit 578a502cd90201a13a88dad6d9d95731eb5dd39a. The local Android HEAD a0e536b52288c76faaf5323d1b81df16f89abefb differs from this tag only in documentation. No Android binary or device run was used to establish this reference.

iOS: e8afccbb87bc5a22e3c3cd9225b9f169e564f8c9 plus the pre-existing example project and scheme edits (combined diff SHA-256 5e5a4ea71d68cc6b23e36e17879ae8fb0c2e7492aa5bd707ec23a8237f028cad) and local OpenSpec artifacts. No SDK Swift sources were edited for this baseline.

Toolchain: arm64 macOS 26.5.2 (25F84), Xcode 26.6 (17F113), Apple Swift 6.3.3. The declared deployment minimum is iOS 16. Available simulator runtimes: iOS 18.6 and iOS 26.5; test destination: iPhone 17 Pro, iOS 26.5 (F21DBAF3-64F6-416E-AC3F-40FA614A6AF6). Full simulator inventory is in inventory.log. This is a local baseline; it does not establish results on CI's configured Xcode 16.4 or on the iOS 16 runtime.

| Check | Result | Evidence |
|---|---|---|
| Swift package manifest and strict swift-format lint | Pass | manifest.log, lint.log |
| Host package tests | 63 passed | host-tests.log |
| Package Debug and Release builds for simulator and device SDKs | 4 passed | package-{Simulator,Device}-{Debug,Release}.log |
| Demo Debug and Release builds for simulator and device SDKs | 4 passed | demo-{Simulator,Device}-{Debug,Release}.log |
| Simulator package tests | 63 passed: 28 + 27 + 8 | package-simulator-tests.log, package.xcresult |
| Simulator demo tests | 7 passed | demo-simulator-tests.log, demo.xcresult |
| OpenSpec strict validation | Pass | openspec validate ios-quality-roadmap --strict |

Commands: swift package describe and swift test with a separate scratch path; xcrun swift-format lint --strict --recursive Package.swift Sources Tests Examples; xcodebuild build with Framewright-Package or FramewrightDemo, Debug/Release, generic simulator/device destination, isolated DerivedData, CODE_SIGNING_ALLOWED=NO; xcodebuild test for the same schemes on the listed simulator with separate result bundles. The matrix passed on the listed toolchain. See [execution evidence](execution-evidence.md) for later checks.

## Stage 0 gate at baseline

- 1.4: the companion inventory classifies all Android event types and SDK/demo areas. Finish per-feature source/availability audits and acceptance traces, especially ABR control, decoder visibility and DRM fields.
- 1.5: local TestPattern.mp4 / ColorBars.mp4 and the package's generated valid/invalid audio fixtures exist. Local playback and deterministic item failure already passed. A versioned multi-variant HLS fixture and controlled throughput/stall/failure recipes still need AVPlayer validation.
- 1.6: obtain physical devices covering the supported floor and representative current hardware; measure repeatable CPU, memory, startup, stall, loss and storage baselines before setting budgets. Device SDK compilation is not hardware validation.
- 1.7: reconcile documentation and make the final Stage 0 gate decision after the remaining evidence is available.

No full Stage 0 gate pass or Android parity claim.
