#!/usr/bin/env bash
# mpris.sh — current MPRIS player info for waybar (custom/script module)
# requires: playerctl

set -uo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

FALLBACK="Nothing is playing"

# ── Helpers ───────────────────────────────────────────────────────────────────

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

player_icon() {
    case "$1" in
        *spotify*)          printf '%s' " "  ;;
        *firefox* | *zen*)  printf '%s' " "  ;;
        *chromium*)         printf '%s' " "  ;;
        *vlc*)              printf '%s' "󰕼 " ;;
        *)                  printf '%s' "  " ;;
    esac
}

output_json() {
    local text="$1" tooltip="${2:-$1}"
    printf '{"text":"%s","tooltip":"%s"}\n' "$(json_escape "$text")" "$(json_escape "$tooltip")"
}

# ── Player selection (prefer Playing over Paused) ─────────────────────────────

playing_player=""
paused_player=""

while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    status="$(playerctl -p "$p" status 2>/dev/null || true)"
    if [[ "$status" == "Playing" ]]; then
        playing_player="$p"
        break
    fi
    [[ "$status" == "Paused" && -z "$paused_player" ]] && paused_player="$p"
done < <(playerctl -l 2>/dev/null || true)

target="${playing_player:-$paused_player}"

if [[ -z "$target" ]]; then
    output_json "$FALLBACK"
    exit 0
fi

# ── Metadata ──────────────────────────────────────────────────────────────────

status="$(playerctl -p "$target" status 2>/dev/null || true)"
title="$(playerctl -p "$target" metadata xesam:title 2>/dev/null || true)"
artist="$(playerctl -p "$target" metadata xesam:artist 2>/dev/null | paste -sd ', ' - || true)"
icon="$(player_icon "$target")"

if [[ -z "$title" ]]; then
    output_json "$FALLBACK"
    exit 0
fi

# ── Output ────────────────────────────────────────────────────────────────────

if [[ "$status" == "Paused" ]]; then
    text="⏸ $icon $title"
else
    text="$icon $title"
fi

tooltip="$title"
[[ -n "$artist" ]] && tooltip="$title — $artist"

output_json "$text" "$tooltip"
