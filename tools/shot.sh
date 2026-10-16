#!/usr/bin/env bash
# Off-screen screenshot (no window pops up, no focus stolen).
# Usage: [SCENE=res://scenes/dev/gallery.tscn] tools/shot.sh <out.png> <WxH> <delay> [client args...]
cd "$(dirname "$0")/.."
G=tools/godot/Godot_v4.7.2-stable_win64_console.exe; [ -f "$G" ] || G=/c/dev/ssfgolf/tools/godot/Godot_v4.7.2-stable_win64_console.exe
out="$1"; res="$2"; delay="$3"; shift 3
timeout 120 "$G" --path client --position -20000,-20000 --resolution "$res" $SCENE -- --offscreen "$@" --screenshot "$out" --shot-delay "$delay" 2>&1 | grep -E "screenshot saved|SCRIPT ERROR|Parse Error|ERROR: [^B]|at: " | head -12
