# Continuous integration and delivery

## Lint checks

The `Swift Lint` job runs the Xcode toolchain's `swift-format` linter in strict mode across the package manifest, sources, tests, and examples. Formatting and supported style-rule violations fail the job. The repository's `.swift-format` sets four-space indentation and a 120-column line length; other rules use the selected toolchain's defaults.

This is formatting and style linting, not a separate SwiftLint or static-analysis service. CI uses the formatter bundled with Xcode 16.4; use that toolchain for identical local results. See the [swift-format documentation](https://github.com/swiftlang/swift-format) for rule coverage.

## Build checks

GitHub Actions runs on pull requests targeting `main`, pushes to `main`, version tags beginning with `v`, and manual dispatches.

The build matrix uses macOS 15 with Xcode 16.4 selected explicitly. It compiles the `Framewright-Package` scheme in Debug and Release for both the iOS Simulator and device SDKs. Code signing is disabled because these checks build library products rather than installable applications.

Each job validates the package manifest and reports its toolchain. Workflow permissions are read-only, checkout credentials are not persisted, and superseded runs on the same ref are cancelled. Dependabot checks GitHub Actions dependencies weekly.

The separate `iOS Tests` job inspects the package manifest for test targets. If none exist, it fails rather than silently skipping validation. It selects an available iPhone simulator and runs `xcodebuild test` using the package scheme. Test failures fail the job, and result bundles are uploaded for diagnosis. Manifest errors and missing simulators fail the job rather than being treated as skipped tests.

The package includes analytics tests. Successful tests establish the covered analytics behavior, not playback correctness or release readiness for the remaining modules.

## Local validation

Run from the repository root:

```sh
xcrun swift-format lint --strict --recursive Package.swift Sources Tests Examples
swift package describe
xcodebuild build -scheme Framewright-Package -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
xcodebuild build -scheme Framewright-Package -configuration Release \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

CI also builds the other two configuration/platform combinations. Local Xcode versions may differ from the CI toolchain.

## Delivery

SPM consumes this repository directly. Source package distribution does not require an App Store deployment, signing credentials, or a package-registry upload.

Release publication remains manual until implementation, tests, licensing, and compatibility validation are ready. No workflow creates tags or GitHub releases. For the first release:

1. Complete the release-readiness checks in the implementation plan.
2. Confirm all CI checks pass for the intended commit on `main`.
3. Create and push a semantic version tag such as `v0.1.0`.
4. Confirm the tag's CI run passes, then publish the GitHub release with compatibility details and release notes.

Pushing a tag makes that version visible to SPM immediately; the tag-triggered CI run is verification, not a publication gate. Do not tag unvalidated commits.

After the first hosted run succeeds, configure branch protection to require `Swift Lint`, the four build checks, and `iOS Tests` before merging. Repository protection settings are managed separately from these workflow files.
