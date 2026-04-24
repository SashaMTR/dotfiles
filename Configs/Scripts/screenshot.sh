#!/bin/bash
# screenshot.sh — capture screen (full or area) and optionally send via KDE Connect
# requires: grim, slurp (area mode), wl-copy, libnotify, paplay
# optional:  kdeconnect-cli (for phone sharing)
#
# usage: screenshot.sh [full|area]   (defaults to full)

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

SCREENSHOT_DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
SOUND="${SCREENSHOT_SOUND:-/usr/share/sounds/freedesktop/stereo/screen-capture.oga}"
KDECONNECT_DEVICE="${KDECONNECT_DEVICE:-}"   # device name filter, empty = first found

# ── Setup ─────────────────────────────────────────────────────────────────────

MODE="${1:-full}"
mkdir -p "$SCREENSHOT_DIR"
FILE="$SCREENSHOT_DIR/Screenshot_$(date +"%d-%m-%Y_%H-%M-%S").png"

# ── Capture ───────────────────────────────────────────────────────────────────

case "$MODE" in
    full)
        if ! grim - | tee "$FILE" | wl-copy; then
            notify-send "❌ Screenshot failed"
            exit 1
        fi
        ;;
    area)
        if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
            notify-send "❌ Not running in Wayland"
            exit 1
        fi

        GEOM=$(slurp 2>/dev/null || true)
        if [[ -z "$GEOM" ]]; then
            notify-send "Screenshot cancelled"
            exit 0
        fi

        if ! grim -g "$GEOM" "$FILE"; then
            notify-send "❌ Screenshot failed"
            exit 1
        fi

        wl-copy < "$FILE"
        ;;
    *)
        echo "Usage: $(basename "$0") [full|area]" >&2
        exit 1
        ;;
esac

# ── Sound ─────────────────────────────────────────────────────────────────────

[[ -f "$SOUND" ]] && paplay "$SOUND" &

# ── KDE Connect ───────────────────────────────────────────────────────────────

_kdeconnect_send() {
    if ! pgrep -x kdeconnectd > /dev/null; then
        kdeconnectd &
        sleep 2
    fi

    local device_id
    if [[ -n "$KDECONNECT_DEVICE" ]]; then
        device_id=$(kdeconnect-cli -a | grep "$KDECONNECT_DEVICE" | cut -d':' -f1 || true)
    else
        device_id=$(kdeconnect-cli -a --id-only 2>/dev/null | head -n 1 || true)
    fi

    if [[ -z "$device_id" ]]; then
        notify-send "⚠️ No KDE Connect device found" "Saved locally"
        return
    fi

    if kdeconnect-cli -d "$device_id" --share "$1"; then
        notify-send "Sent to your phone" "$(basename "$1")"
    else
        notify-send "⚠️ Send failed" "Saved locally"
    fi
}

_kdeconnect_send "$FILE"
