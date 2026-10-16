#!/usr/bin/env bash
# Frame-time probe (uncapped, vsync off). Usage: tools/perf.sh <label> [client args...]
# Prints mean/p95/p99/worst frame times measured by Router._dev_perf_hook.
cd "$(dirname "$0")/.."
G=tools/godot/Godot_v4.7.2-stable_win64_console.exe; [ -f "$G" ] || G=/c/dev/ssfgolf/tools/godot/Godot_v4.7.2-stable_win64_console.exe
label="$1"; shift
out=$(timeout 120 "$G" --path client --disable-vsync --position -20000,-20000 --resolution 1920x1080 -- --offscreen "$@" --perf-log 6 --perf-warmup 3 2>&1 | grep "perf:")
echo "$label: ${out#perf: }"
