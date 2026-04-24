#!/bin/bash
# lockscreen.sh — pick a random wallpaper for hyprlock then lock
# requires: hyprlock, libnotify

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

WALL_DIR="${WALLPAPER_DIR:-$HOME/Wallpapers}"
CACHE_WALL="${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock_wall.png"

# ── Validation ────────────────────────────────────────────────────────────────

if [[ ! -d "$WALL_DIR" ]]; then
    echo "Error: wallpaper directory '$WALL_DIR' not found" >&2
    exit 1
fi

IMG=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \
    -o -iname "*.jpeg" -o -iname "*.webp" \) | shuf -n 1)

if [[ -z "$IMG" ]]; then
    echo "Error: no wallpaper found in '$WALL_DIR'" >&2
    exit 1
fi

# ── Apply & Lock ──────────────────────────────────────────────────────────────

cp "$IMG" "$CACHE_WALL"
exec hyprlock
