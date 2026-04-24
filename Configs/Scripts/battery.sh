#!/bin/bash
# battery.sh — animated battery status for waybar (custom/script module)
# requires: /sys/class/power_supply/BAT0

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

BATTERY="${BATTERY_NAME:-BAT0}"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/battery_anim_index"
ICONS=("󰂎" "󱊡" "󱊢" "󱊣")

# ── Init ──────────────────────────────────────────────────────────────────────

BATTERY_PATH="/sys/class/power_supply/$BATTERY"

if [[ ! -d "$BATTERY_PATH" ]]; then
    echo '{"text": "󰂑 No battery", "class": "unknown"}'
    exit 0
fi

[[ -f "$STATE_FILE" ]] || echo 0 > "$STATE_FILE"
i=$(< "$STATE_FILE")

capacity=$(< "$BATTERY_PATH/capacity")
status=$(< "$BATTERY_PATH/status")

# ── Output ────────────────────────────────────────────────────────────────────

if (( capacity <= 15 )); then
    echo "{\"text\": \"󰂃 Connect charger ${capacity}%\", \"class\": \"critical\"}"

elif (( capacity <= 25 )); then
    echo "{\"text\": \"󰂃 Battery low ${capacity}%\", \"class\": \"warning\"}"

elif [[ "$status" == "Full" ]]; then
    echo "{\"text\": \"󰁹 Battery full ${capacity}%\", \"class\": \"full\"}"

elif [[ "$status" == "Charging" ]]; then
    echo "{\"text\": \"${ICONS[$i]} Charging ${capacity}%\", \"class\": \"charging\"}"
    echo $(( (i + 1) % ${#ICONS[@]} )) > "$STATE_FILE"

else
    echo "{\"text\": \"󰁹 ${capacity}%\", \"class\": \"normal\"}"
fi
