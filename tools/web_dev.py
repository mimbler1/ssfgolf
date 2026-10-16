"""Local browser build with live reload.

Exports the client with the "Web" preset into build/web, serves it on http://localhost:8060,
re-exports whenever a file under client/ changes, and reloads open browser tabs after each build.

    python tools/web_dev.py                # watch local edits
    python tools/web_dev.py --pull 30      # also `git pull` every 30 s, so pushes from anywhere show up
    python tools/web_dev.py --port 9000 --release

Only offline modes (Practice, Studio) work in the browser: online play uses ENet over UDP,
which browsers cannot open.
"""

from __future__ import annotations

import argparse
import http.server
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLIENT = ROOT / "client"
OUT = ROOT / "build" / "web"
GODOT = ROOT / "tools" / "godot" / "Godot_v4.7.2-stable_win64_console.exe"
IGNORED_DIRS = {".godot", "tests"}
POLL_S = 1.0
DEBOUNCE_S = 1.0

# Polls the server for the build number and reloads the page when it changes.
RELOAD_SNIPPET = b"""<script>
(() => {
  let seen = null;
  setInterval(async () => {
    try {
      const r = await fetch('/__build', {cache: 'no-store'});
      const id = await r.text();
      if (seen !== null && id !== seen) location.reload();
      seen = id;
    } catch (e) {}
  }, 1000);
})();
</script>"""

state_lock = threading.Lock()
build_id = 0


def log(msg: str) -> None:
    print(time.strftime("[%H:%M:%S] ") + msg, flush=True)


def snapshot() -> dict[str, float]:
    files: dict[str, float] = {}
    for dirpath, dirnames, filenames in os.walk(CLIENT):
        dirnames[:] = [d for d in dirnames if d not in IGNORED_DIRS]
        for name in filenames:
            p = os.path.join(dirpath, name)
            try:
                files[p] = os.path.getmtime(p)
            except OSError:
                pass
    return files


def export(release: bool) -> bool:
    global build_id
    OUT.mkdir(parents=True, exist_ok=True)
    mode = "--export-release" if release else "--export-debug"
    log("Exporting...")
    started = time.time()
    proc = subprocess.run(
        [str(GODOT), "--headless", "--path", str(CLIENT), mode, "Web", str(OUT / "index.html")],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    errors = [l for l in (proc.stdout + proc.stderr).splitlines() if "ERROR" in l or "SCRIPT ERROR" in l]
    ok = proc.returncode == 0 and (OUT / "index.pck").exists()
    if ok:
        with state_lock:
            build_id += 1
    for line in errors[:20]:
        print("  " + line, flush=True)
    log(f"Build {build_id} ready in {time.time() - started:.1f}s" if ok
        else f"Export failed (exit {proc.returncode}); keeping the previous build")
    return ok


def watch(release: bool) -> None:
    before = snapshot()
    while True:
        time.sleep(POLL_S)
        now = snapshot()
        if now == before:
            continue
        # Wait until edits settle so a save burst (or a git pull) triggers one build.
        while True:
            time.sleep(DEBOUNCE_S)
            settled = snapshot()
            if settled == now:
                break
            now = settled
        changed = {p for p in now.keys() | before.keys() if now.get(p) != before.get(p)}
        sample = ", ".join(os.path.relpath(p, CLIENT) for p in sorted(changed)[:3])
        log(f"{len(changed)} file(s) changed ({sample}{', ...' if len(changed) > 3 else ''})")
        before = now
        export(release)
        before = snapshot()  # ignore files the export itself touched (import cache, .uid files)


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True)


def pull_loop(interval: int) -> None:
    branch = git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    log(f"Pulling origin/{branch} every {interval}s")
    while True:
        time.sleep(interval)
        if git("fetch", "--quiet", "origin", branch).returncode != 0:
            continue
        local = git("rev-parse", "HEAD").stdout.strip()
        remote = git("rev-parse", f"origin/{branch}").stdout.strip()
        if local == remote:
            continue
        result = git("pull", "--ff-only", "--quiet", "origin", branch)
        if result.returncode == 0:
            log(f"Pulled {git('log', '-1', '--format=%h %s').stdout.strip()}")
        else:
            log("git pull failed (local changes or diverged branch?): " + result.stderr.strip())


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(OUT), **kwargs)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        if path == "/__build":
            with state_lock:
                body = str(build_id).encode()
            self._send(body, "text/plain")
        elif path in ("/", "/index.html"):
            html = (OUT / "index.html").read_bytes()
            self._send(html.replace(b"</body>", RELOAD_SNIPPET + b"</body>"), "text/html")
        else:
            super().do_GET()

    def _send(self, body: bytes, ctype: str) -> None:
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args) -> None:
        pass


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True


Handler.extensions_map.update({".wasm": "application/wasm", ".pck": "application/octet-stream"})


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", type=int, default=8060)
    ap.add_argument("--pull", type=int, metavar="SECONDS", default=0,
                    help="also fetch and fast-forward from origin every SECONDS")
    ap.add_argument("--release", action="store_true", help="export release instead of debug")
    args = ap.parse_args()

    if not GODOT.exists():
        sys.exit("Godot 4.7.2 not found in tools/godot. See README.md > Setup.")
    if not export(args.release) and not (OUT / "index.html").exists():
        sys.exit("First export failed. Are the web export templates installed? (tools/get-godot.ps1 -WebTemplates)")

    threading.Thread(target=watch, args=(args.release,), daemon=True).start()
    if args.pull > 0:
        threading.Thread(target=pull_loop, args=(args.pull,), daemon=True).start()

    server = Server(("127.0.0.1", args.port), Handler)
    log(f"Serving on http://localhost:{args.port}  (Ctrl+C to stop)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
