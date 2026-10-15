"""End-to-end online test: backend + dedicated server + two headless clients.

Requires Postgres running (`docker compose up -d postgres`) and `npm install` in /backend.
Run from the repo root:  python tools/e2e_online.py

Steps: start backend -> start registered game server -> create two guest accounts ->
both queue for Quick Play -> wait for a match -> run two headless test clients with the
signed join tokens -> verify the match result and rewards via the public API.
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, "tools", "godot", "Godot_v4.7.2-stable_win64_console.exe")
CLIENT = os.path.join(ROOT, "client")
API = "http://127.0.0.1:8090"
LOGS = os.path.join(ROOT, "tools", ".e2e_logs")
GAME_PORT = "7811"
procs = []


def call(method, path, body=None, token=None, ok=(200, 204)):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read()
        return e.code, (json.loads(raw) if raw else None)


def wait_health():
    for _ in range(60):
        try:
            s, _ = call("GET", "/health")
            if s == 200:
                return
        except Exception:
            pass
        time.sleep(0.5)
    raise SystemExit("backend did not become healthy")


def main():
    env = dict(os.environ, PORT="8090", MM_FILL_WAIT_MS="2000", LOG_LEVEL="warn")
    os.makedirs(LOGS, exist_ok=True)
    backend = subprocess.Popen(["node", "src/index.ts"], cwd=os.path.join(ROOT, "backend"), env=env,
                               stdout=open(os.path.join(LOGS, "backend.log"), "w"), stderr=subprocess.STDOUT, text=True)
    procs.append(backend)
    wait_health()
    print("backend healthy")
    server = subprocess.Popen([GODOT, "--headless", "--path", CLIENT, "--", "--server", "--port", GAME_PORT,
                               "--backend", API, "--public-host", "127.0.0.1"],
                              stdout=open(os.path.join(LOGS, "server.log"), "w"), stderr=subprocess.STDOUT, text=True)
    procs.append(server)

    players = []
    for name in ("E2E_Alpha", "E2E_Bravo"):
        s, d = call("POST", "/v1/auth/guest", {"displayName": name})
        assert s == 200, (s, d)
        players.append({"name": name, "token": d["sessionToken"], "id": d["playerId"], "trophies": d["profile"]["trophies"]})
    print("created guests:", [p["name"] for p in players])
    # The first player plays as a roster character.
    s, me = call("GET", "/v1/me", token=players[0]["token"])
    s, d = call("PATCH", "/v1/me", {"appearance": dict(me["appearance"], character="ace")}, players[0]["token"])
    assert s == 200 and d["appearance"]["character"] == "ace", (s, d)

    time.sleep(2.0)  # let the game server register
    for p in players:
        s, d = call("POST", "/v1/matchmaking/queue", {"mode": "quick"}, p["token"])
        assert s == 200, (s, d)
    deadline = time.time() + 40
    for p in players:
        while True:
            s, d = call("GET", "/v1/matchmaking/status", token=p["token"])
            if d and d.get("status") == "matched":
                p["match"] = d["match"]
                break
            if time.time() > deadline:
                raise SystemExit("not matched in time: %s" % d)
            time.sleep(0.5)
    match_id = players[0]["match"]["matchId"]
    assert players[1]["match"]["matchId"] == match_id
    print("matched:", match_id, "server", players[0]["match"]["serverHost"], players[0]["match"]["serverPort"])

    clients = []
    for p in players:
        m = p["match"]
        c = subprocess.Popen([GODOT, "--headless", "--path", CLIENT, "res://tests/net_test_client.tscn", "--",
                              "--connect", "%s:%s" % (m["serverHost"], m["serverPort"]), "--dev-name", p["name"],
                              "--token", m["joinToken"], "--match", match_id, "--quit-after", "300"],
                             stdout=open(os.path.join(LOGS, "client_%s.log" % p["name"]), "w"), stderr=subprocess.STDOUT, text=True)
        procs.append(c)
        clients.append((c, p["name"]))
    codes = []
    for c, name in clients:
        c.wait(timeout=330)
        codes.append(c.returncode)
        with open(os.path.join(LOGS, "client_%s.log" % name)) as f:
            out = f.read()
        for line in out.splitlines():
            if line.startswith("[") and ("MATCH_END" in line or "welcomed" in line or "lost" in line or "TIMEOUT" in line):
                print("  client:", line[:300])
        # Both players emote with the last catalogue id; everyone (sender included) sees both.
        emotes = [l for l in out.splitlines() if "EMOTE slot" in l and l.rstrip().endswith("id 7")]
        assert len(emotes) >= 2, "client %s saw emotes %s" % (name, emotes)
        # The first player's roster character travels backend -> server -> every client.
        assert "=ace" in out, "client %s did not see the roster character" % name
    assert codes == [0, 0], codes

    deadline = time.time() + 30
    result = None
    while time.time() < deadline:
        s, d = call("GET", "/v1/matches/" + match_id, token=players[0]["token"])
        if s == 200:
            result = d
            break
        time.sleep(1.0)
    assert result, "match result never became available"
    print("result:", json.dumps(result["players"]))
    for p in players:
        s, d = call("GET", "/v1/matches/" + match_id, token=p["token"])
        r = d["myRewards"]
        s2, me = call("GET", "/v1/me", token=p["token"])
        print("  %s: trophyDelta=%+d xp=%d coins=%d -> trophies %d, matches %d, wins %d" % (
            p["name"], r["trophyDelta"], r["xpGained"], r["coinsGained"], me["trophies"], me["stats"]["matches"], me["stats"]["wins"]))
        assert me["stats"]["matches"] == 1
    winner = [x for x in result["players"] if x["placement"] == 1][0]
    print("winner:", winner["displayName"])
    s, d = call("GET", "/v1/matchmaking/status", token=players[0]["token"])
    assert d["status"] == "idle", d
    print("E2E PASSED")


if __name__ == "__main__":
    try:
        main()
    finally:
        for p in procs:
            if p.poll() is None:
                p.kill()
        for p in procs[1:2]:
            try:
                out = p.stdout.read() if p.stdout else ""
                tail = [l for l in out.splitlines() if l.startswith("[2")][-12:]
                print("server log tail:\n  " + "\n  ".join(tail))
            except Exception:
                pass
