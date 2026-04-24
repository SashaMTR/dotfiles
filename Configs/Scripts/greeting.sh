#!/bin/bash
# greeting.sh — time-based greeting for hyprlock or waybar
# usage: greeting.sh [--json]

set -euo pipefail

# ── Greeting ──────────────────────────────────────────────────────────────────

hour=$(date +%H)

if   (( hour >=  5 && hour < 12 )); then greeting="Good Morning"
elif (( hour >= 12 && hour < 17 )); then greeting="Good Afternoon"
elif (( hour >= 17 && hour < 21 )); then greeting="Good Evening"
else                                      greeting="Good Night"
fi

# ── Output ────────────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--json" ]]; then
    printf '{"text": "%s"}\n' "$greeting"
else
    echo "$greeting"
fi
