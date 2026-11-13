#!/usr/bin/env python3
"""Generate and serve a synthetic Framewright HLS test fixture."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import shutil
import subprocess
import time
from urllib.parse import urlsplit

VERSION = "v1"
VARIANTS = ((320, 180, 350), (640, 360, 850), (960, 540, 1800))


def generate(root):
    root.mkdir(parents=True, exist_ok=True)
    if any(root.iterdir()):
        raise SystemExit("Use a new, empty fixture directory.")
    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is required.")
    master = ["#EXTM3U", "#EXT-X-VERSION:3", "#EXT-X-INDEPENDENT-SEGMENTS"]
    for width, height, rate in VARIANTS:
        variant = root / str(height)
        variant.mkdir()
        subprocess.run(
            [
                "ffmpeg", "-hide_banner", "-loglevel", "error",
                "-f", "lavfi", "-i", f"testsrc2=size={width}x{height}:rate=24",
                "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
                "-t", "48", "-threads", "2", "-c:v", "libx264", "-preset", "fast",
                "-pix_fmt", "yuv420p", "-g", "48", "-keyint_min", "48", "-sc_threshold", "0",
                "-b:v", f"{rate}k", "-minrate", f"{rate}k", "-maxrate", f"{rate}k",
                "-bufsize", f"{rate * 2}k", "-x264-params", "nal-hrd=cbr",
                "-c:a", "aac", "-b:a", "64k",
                "-hls_time", "2", "-hls_playlist_type", "vod",
                "-hls_flags", "independent_segments",
                "-hls_segment_filename", str(variant / "segment%03d.ts"),
                str(variant / "index.m3u8"),
            ],
            check=True,
        )
        peak = (rate + 64) * 1150
        master.extend([
            f"#EXT-X-STREAM-INF:BANDWIDTH={peak},RESOLUTION={width}x{height},FRAME-RATE=24",
            f"{height}/index.m3u8",
        ])
    (root / "master.m3u8").write_text("\n".join(master) + "\n")
    (root / "invalid.mp4").write_bytes(b"Framewright invalid media fixture\n")
    (root / "fixture-version.txt").write_text(VERSION + "\n")


def serve(root, bind, port, kbps, delay_segment, delay_seconds, fail_segment):
    if not (root / "master.m3u8").is_file():
        raise SystemExit("Generate the fixture first.")

    class Handler(SimpleHTTPRequestHandler):
        extensions_map = {
            **SimpleHTTPRequestHandler.extensions_map,
            ".m3u8": "application/vnd.apple.mpegurl",
            ".ts": "video/mp2t",
        }

        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(root), **kwargs)

        def send_head(self):
            name = Path(urlsplit(self.path).path).name
            if name == fail_segment:
                self.send_error(503, "Injected fixture failure")
                return None
            if name == delay_segment and delay_seconds:
                time.sleep(delay_seconds)
            return super().send_head()

        def copyfile(self, source, output):
            if not kbps or not urlsplit(self.path).path.endswith(".ts"):
                super().copyfile(source, output)
                return
            started = time.monotonic()
            sent = 0
            while chunk := source.read(8192):
                sent += len(chunk)
                time.sleep(max(0, started + sent * 8 / (kbps * 1000) - time.monotonic()))
                try:
                    output.write(chunk)
                except (BrokenPipeError, ConnectionResetError):
                    return

    with ThreadingHTTPServer((bind, port), Handler) as server:
        print(f"http://{bind}:{server.server_port}/master.m3u8", flush=True)
        server.serve_forever()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("generate").add_argument("root", type=Path)
    server = commands.add_parser("serve")
    server.add_argument("root", type=Path)
    server.add_argument("--bind", default="127.0.0.1")
    server.add_argument("--port", type=int, default=8765)
    server.add_argument("--kbps", type=int, default=0, help="Rate limit per segment response; 0 disables it.")
    server.add_argument("--delay-segment")
    server.add_argument("--delay-seconds", type=float, default=0)
    server.add_argument("--fail-segment")
    args = parser.parse_args()
    if args.command == "generate":
        generate(args.root.resolve())
    else:
        if args.kbps < 0 or args.delay_seconds < 0:
            parser.error("Rate and delay cannot be negative.")
        serve(args.root.resolve(), args.bind, args.port, args.kbps, args.delay_segment, args.delay_seconds,
              args.fail_segment)


if __name__ == "__main__":
    main()
