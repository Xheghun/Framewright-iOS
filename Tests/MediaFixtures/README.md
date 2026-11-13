# Controlled HLS fixture v1

Generate a 48-second synthetic HLS VOD with three aligned H.264/AAC variants, two-second segments, and an invalid media file. Requires Python 3 and FFmpeg with libx264; no remote assets or credentials.

```sh
python3 Tests/MediaFixtures/hls_fixture.py generate /tmp/framewright-hls-v1
python3 Tests/MediaFixtures/hls_fixture.py serve /tmp/framewright-hls-v1
```

Open the printed master URL in a local AVPlayer test host. The demo URL form currently accepts HTTPS only; keep that validation and use a separate test host for loopback HTTP. To run on a physical device, configure a trusted HTTPS local endpoint or an explicitly scoped test-host transport exception; do not modify production transport policy.

- Healthy: advance past 2 seconds on the master URL.
- Invalid: open `invalid.mp4`; require AVPlayerItem failure.
- HTTP failure: add `--fail-segment segment023.ts` and request a matching segment; the server deterministically returns 503. Whether AVPlayer retries or recovers is a separate playback observation.
- Stall: add `--delay-segment segment006.ts --delay-seconds 12`; check the request trace and actual playhead/wait state. Delay does not imply a stall if the buffer covers it.
- Rate profiles: run separately with `--kbps 600`, `--kbps 1400` and `--kbps 3200`; limits are per segment response, not aggregate network shaping. Compare requested variants and timestamps; use a single-request control or external shaping for aggregate throughput assertions.

On macOS 26.5.2, AVPlayer reached 2.09 s of playback and reported terminal failure for invalid media. The injected segment returned HTTP 503. Indicated bitrate was unavailable in the early access-log samples; this test is not evidence of adaptive selection or hardware stall coverage.

To run the opt-in package integration checks from a simulator, leave the server running:

```sh
TEST_RUNNER_FRAMEWRIGHT_HLS_TEST_URL=http://127.0.0.1:8765/ \
  xcodebuild test -scheme Framewright-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:FramewrightAVPlayerAdapterTests \
  -only-testing:FramewrightCodecInspectorTests CODE_SIGNING_ALLOWED=NO
```

The tests validate playhead progress, terminal diagnostics for invalid media, and the declared
variant inventory. Without the environment variable they are explicitly skipped. Server logs
show the injected 503; a successful test does not establish aggregate throughput or ABR behavior.
