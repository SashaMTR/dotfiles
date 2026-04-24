#!/bin/bash
# wallpaper.sh — pick a random wallpaper and apply it via swww
# requires: swww, libnotify

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

WALL_DIR="${WALLPAPER_DIR:-$HOME/Wallpapers}"
TRANSITION_TYPE="${WALL_TRANSITION:-wipe}"
TRANSITION_DURATION="${WALL_DURATION:-0.8}"
TRANSITION_FPS="${WALL_FPS:-60}"

# ── Validation ────────────────────────────────────────────────────────────────

if [[ ! -d "$WALL_DIR" ]]; then
    echo "Error: wallpaper directory '$WALL_DIR' not found" >&2
    exit 1
fi

WALL=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \
    -o -iname "*.jpeg" -o -iname "*.webp" \) | shuf -n 1)

if [[ -z "$WALL" ]]; then
    echo "Error: no wallpaper found in '$WALL_DIR'" >&2
    exit 1
fi

# ── Daemon ────────────────────────────────────────────────────────────────────

if ! pgrep -x swww-daemon > /dev/null; then
    swww-daemon &
    sleep 0.5
fi

# ── Apply ─────────────────────────────────────────────────────────────────────

swww img "$WALL" \
    --transition-type "$TRANSITION_TYPE" \
    --transition-duration "$TRANSITION_DURATION" \
    --transition-fps "$TRANSITION_FPS"

notify-send "Wallpaper" "$(basename "$WALL")" --icon "$WALL"
