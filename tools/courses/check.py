"""Builds a course module, runs the solver report and renders review maps.

  python tools/courses/check.py <course_id> [--hole N] [--out DIR]

Course modules live next to this file (tools/courses/<course_id>.py) and write
client/data/courses/<course_id>.json when imported with build().
"""
import importlib
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
GODOT = os.path.join(ROOT, "tools", "godot", "Godot_v4.7.2-stable_win64_console.exe")
sys.path.insert(0, HERE)


def main():
    cid = sys.argv[1]
    hole = sys.argv[sys.argv.index("--hole") + 1] if "--hole" in sys.argv else None
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else os.path.join(tempfile.gettempdir(), "course_maps", cid)
    importlib.import_module(cid).build()
    rep = os.path.join(tempfile.gettempdir(), "course_report_%s.json" % cid)
    cmd = [GODOT, "--headless", "--path", os.path.join(ROOT, "client"), "--script", "res://tests/course_report.gd",
           "--", "--course", cid, "--out", rep]
    if hole is not None:
        cmd += ["--hole", hole]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    import preview
    sys.argv = ["preview", rep, out]
    preview.main()
    print("maps:", out)


if __name__ == "__main__":
    main()
