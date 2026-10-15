#!/usr/bin/env bash
# Runs the pinned Godot build against the client project. Usage: tools/godot.sh [godot args...]
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/godot/Godot_v4.7.2-stable_win64_console.exe" --path "$DIR/../client" "$@"
