"""Multi-client online soak test: one dedicated server + N headless bot clients (2-6).

  python tools/e2e_multi.py [N] [--target POINTS] [--no-abilities]

The server runs in insecure dev mode (no backend) on the full six-course pool. Every bot
auto-aims with the shared physics predictor, fires random abilities with spin and triggers them
mid-flight, so many balls collide, explode and race at once. Passes when every client reaches
MATCH_END with identical standings and the server log has no script errors.
Logs: build/e2e_multi/.
"""
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, "tools", "godot", "Godot_v4.7.2-stable_win64_console.exe")
CLIENT = os.path.join(ROOT, "client")
LOGS = os.path.join(ROOT, "build", "e2e_multi")
PORT = "7795"
NAMES = ["Alpha@rex", "Bravo@mira", "Charlie@bjorn", "Delta@ace", "Echo@nana", "Foxtrot@bolt"]


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 6
    target = sys.argv[sys.argv.index("--target") + 1] if "--target" in sys.argv else "6"
    abilities = "--no-abilities" not in sys.argv
    os.makedirs(LOGS, exist_ok=True)
    t0 = time.time()
    server = subprocess.Popen([GODOT, "--headless", "--path", CLIENT, "--", "--server", "--port", PORT, "--insecure-dev",
                               "--dev-players", str(n), "--dev-target", target],
                              stdout=open(os.path.join(LOGS, "server.log"), "w"), stderr=subprocess.STDOUT, text=True)
    time.sleep(3)
    clients = []
    for i in range(n):
        args = [GODOT, "--headless", "--path", CLIENT, "res://tests/net_test_client.tscn", "--",
                "--connect", "127.0.0.1:" + PORT, "--dev-name", NAMES[i], "--quit-after", "900"]
        if abilities:
            args.append("--abilities")
        clients.append(subprocess.Popen(args, stdout=open(os.path.join(LOGS, "client_%d.log" % i), "w"),
                                        stderr=subprocess.STDOUT, text=True))
    codes = [c.wait() for c in clients]
    server.terminate()
    server.wait()
    standings = []
    ok = True
    for i in range(n):
        log = open(os.path.join(LOGS, "client_%d.log" % i), encoding="utf-8", errors="replace").read()
        m = re.search(r"MATCH_END reason=(\w+) standings=(\[.*?\]) shots=(\d+) abilities=(\d+) events=(\{.*?\})", log)
        welcomed = re.search(r"welcomed as slot (\d+), (\d+) players", log)
        if not m or not welcomed:
            print("client %d: no MATCH_END (exit %d)" % (i, codes[i]))
            ok = False
            continue
        st = json.loads(m.group(2))
        ev = json.loads(m.group(5))
        standings.append([(s["name"], s["points"], s["placement"]) for s in st])
        print("client %d %-8s slot %s/%s players  reason=%s shots=%s abilities=%s explosions=%s holes=%s" % (
            i, NAMES[i].split("@")[0], welcomed.group(1), welcomed.group(2), m.group(1), m.group(3), m.group(4),
            ev.get("explode", 0), ev.get("hole_end", 0)))
        if int(welcomed.group(2)) != n:
            ok = False
        if "SCRIPT ERROR" in log:
            print("  client %d log has SCRIPT ERROR" % i)
            ok = False
    if standings and any(s != standings[0] for s in standings):
        print("STANDINGS DIFFER between clients")
        ok = False
    elif standings:
        print("standings (all clients agree):", standings[0])
    slog = open(os.path.join(LOGS, "server.log"), encoding="utf-8", errors="replace").read()
    if "SCRIPT ERROR" in slog:
        print("server log has SCRIPT ERROR")
        ok = False
    print("elapsed %.0fs" % (time.time() - t0))
    print("E2E MULTI %s (%d players)" % ("PASSED" if ok else "FAILED", n))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
