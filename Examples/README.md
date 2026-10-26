# SwiftUI sample

Open [`FramewrightDemo/FramewrightDemo.xcodeproj`](FramewrightDemo/FramewrightDemo.xcodeproj) and run the `FramewrightDemo` scheme on an iPhone or simulator. The app uses the repository's local Swift package; no package checkout or project generator is required. For a physical device, select your development team in Signing & Capabilities.

The app owns its AVPlayer and attaches Framewright diagnostics. It opens with the Big Buck Bunny trailer and includes the Sintel trailer, two silent offline test videos, HTTPS media loading, play/pause, tracked five-second seeks, replay, item replacement, live events, and JSON export. Playback pauses when the app becomes inactive and does not resume automatically.

Use **Choose video** to select **Big Buck Bunny**, **Sintel**, an offline test video, or an HTTPS stream. The film trailers require an internet connection. Tap the video for native playback controls. The top-right **Playback actions** menu provides tracked five-second seeks and **Replay as new session**. Open **Session activity** to inspect events, select a session, or export JSON to Files. Live display retains 200 events across 10 sessions; each session's export retains up to 500 events and includes the package's truncation flag. Export during playback produces a snapshot; finish playback or replace the item before exporting a completed run.

## Measurement limits

SwiftUI's `VideoPlayer` does not provide a confirmed first-render callback. This sample therefore does not publish first-frame events or claim first-frame-dependent rebuffer measurements. Readiness and visible progress are not substituted for those metrics. Pause/resume transitions and timeline jumps from native controls appear in Session activity. Timeline jumps are recorded as `POSITION_DISCONTINUITY` because AVPlayer does not identify their cause. The menu’s seek hooks additionally exclude seek-related buffering.

Default URI sanitization removes credentials, queries, fragments, and local paths. HTTP URL paths remain visible in exports. Diagnostic delivery errors show an incomplete-data warning; restart the app before another validation run.

## Validation

Run the `FramewrightDemo` scheme's tests in Xcode. CI builds the app for device and simulator in Debug and Release and runs its integration tests on a simulator.

For physical-device validation:

1. Play both bundled videos. Verify visible motion on the test pattern, pause/resume, seeking, natural completion, and replay. Confirm each replacement/replay has a distinct session and the previous session ends once.
2. Background the app during playback and during replay. Verify it remains paused after returning and does not resume from a stale seek completion.
3. Load an HTTPS HLS stream you control. After playback starts, interrupt its segment delivery, wait for buffered content to drain, and restore delivery. Observe Waiting/Playing transitions and recovery. This checks player behavior; it does not validate first-frame timing or rebuffer summaries.
4. Export both a replaced and completed session. Check the session IDs, terminal reasons, URI redaction, and any truncation/incomplete-data warnings.

Simulator tests do not establish physical-device rendering or network-stall behavior. Record device, OS version, stream, and observed results when performing these checks.

The bundled MP4 files are synthetic FFmpeg test patterns, not third-party footage. FFmpeg is only needed to regenerate them:

```sh
ffmpeg -f lavfi -i 'testsrc2=size=640x360:rate=24:duration=12' -an -c:v libx264 -pix_fmt yuv420p -movflags +faststart TestPattern.mp4
ffmpeg -f lavfi -i 'smptebars=size=640x360:rate=24:duration=12' -an -c:v libx264 -pix_fmt yuv420p -movflags +faststart ColorBars.mp4
```

## Film credits

- **Big Buck Bunny**: (c) copyright 2008, Blender Foundation / www.bigbuckbunny.org. [Attribution and license](https://peach.blender.org/about/). [Trailer](https://media.w3.org/2010/05/bunny/trailer.mp4).
- **Sintel**: © 2010 Blender Foundation. [Attribution and license](https://durian.blender.org/about/). [Trailer](https://media.w3.org/2010/05/sintel/trailer.mp4).

Both films are licensed under [Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/). The sample streams unmodified trailers hosted by W3C; the films are not bundled with the app. Credits and license links are also available in the video picker.
