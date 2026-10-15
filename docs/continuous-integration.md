# Continuous integration and delivery

## Build checks

GitHub Actions runs on pull requests targeting `main`, pushes to `main`, version tags beginning with `v`, and manual dispatches.

The build matrix uses macOS 15 with Xcode 16.4 selected explicitly. It compiles the `Framewright-Package` scheme in Debug and Release for both the iOS Simulator and device SDKs. Code signing is disabled because these checks build library products rather than installable applications.

Each job validates the package manifest and reports its toolchain. Workflow permissions are read-only, checkout credentials are not persisted, and superseded runs on the same ref are cancelled. Dependabot checks GitHub Actions dependencies weekly.

The current checks establish that the package compiles. There are no test targets, and successful builds do not establish playback correctness or release readiness. Add simulator test execution when the first test target is introduced; test failures must fail CI.

## Local validation

Run from the repository root:

```sh
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

After the first hosted run succeeds, configure branch protection to require the four build checks before merging. Repository protection settings are managed separately from these workflow files.
