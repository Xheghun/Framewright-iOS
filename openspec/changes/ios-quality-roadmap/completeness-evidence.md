# Tasks 2.1–2.3 verification

Verified 2026-11-13 against working changes based on `e622519674c3c9f40efd34a33f965983d7dec65f`.
Scope: only tasks 2.1–2.3. No Stage 0 or full Stage 1 gate is claimed.
Pre-existing demo project/scheme modifications were preserved. `.agents/` and `openspec/` were already untracked.
Toolchain: Xcode 26.6 (17F113), Apple Swift 6.3.3; arm64 macOS host, iPhone 17 Pro simulator on iOS 26.5 (F21DBAF3-64F6-416E-AC3F-40FA614A6AF6).

## Results

- `swift test --scratch-path /tmp/framewright-completeness-tests --filter 'FramewrightAnalyticsTests|FramewrightDiagnosticsOverlayTests'`: 35 tests passed. Log: `/tmp/framewright-completeness-host-tests.log`.
- `xcodebuild -project Examples/FramewrightDemo/FramewrightDemo.xcodeproj -scheme FramewrightDemo -destination 'platform=iOS Simulator,id=F21DBAF3-64F6-416E-AC3F-40FA614A6AF6' -derivedDataPath /tmp/framewright-completeness-demo -resultBundlePath /tmp/framewright-completeness-demo-verified.xcresult -only-testing:FramewrightDemoTests test`: 7 tests passed. Log: `/tmp/framewright-completeness-demo-verified.log`.
- `xcrun swift-format lint --strict` over the seven changed Swift files: passed.
- `git diff --check`: passed.

Expected and observed: legacy v2/v3 inputs omit delivery completeness; optional nil/false/true values round-trip independently of truncation; invalid types are rejected. Overlay exports preserve incomplete-only, truncated-only, both and unspecified metadata. Known snapshot loss cannot be cleared by a false host signal. Export rejects stale state after selection changes. A failing sample sink invokes the real adapter error callback, sets the selected session warning, and yields `deliveryIncomplete: true` without truncation. Earlier-session exports retain the flag after replacement/disconnect/reconnect; a recovered connection exports unspecified completeness.

The callback has no session ID. The sample conservatively flags every session created on an affected connection, including subsequent sessions on that connection; it does not claim exact loss attribution. Documentation covers this responsibility and older readers ignoring the additive v3 field. The failure test exercises sink errors; it does not claim queue-overflow recovery coverage (task 2.6).

## Verification corrections

Initial sandboxed tools could not access compiler caches/CoreSimulator; authorized reruns succeeded. A default build encountered stale test objects after the initializer change; the clean scratch build resolved this. The first new invalid-type assertion expected DecodingError, but the codec intentionally wraps it in CodecError; the assertion was corrected. An initial sample filter selected zero tests; it is not counted as evidence. The subsequent full sample target executed seven tests successfully. No physical-device or broader roadmap validation is claimed. Temporary result bundles/logs are local artifacts.
