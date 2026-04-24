#!/bin/bash
# install.sh — deploy dotfiles from ~/dotfiles/Configs/ to ~/.config/
# usage: bash install.sh [--dry-run]
#
# requires: stow OR plain cp (fallback)

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CONFIGS_DIR="$DOTFILES_DIR/Configs"
TARGET_DIR="$HOME/.config"
DRY_RUN=false

# ── Args ──────────────────────────────────────────────────────────────────────

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────

info()    { echo -e "\e[34m  ➤\e[0m  $*"; }
success() { echo -e "\e[32m  ✔\e[0m  $*"; }
warn()    { echo -e "\e[33m  ⚠\e[0m  $*"; }
dry()     { echo -e "\e[90m  ~\e[0m  [dry] $*"; }

run() {
    if $DRY_RUN; then
        dry "$*"
    else
        "$@"
    fi
}

# ── Validation ────────────────────────────────────────────────────────────────

if [[ ! -d "$CONFIGS_DIR" ]]; then
    echo "Error: '$CONFIGS_DIR' not found"
    exit 1
fi

$DRY_RUN && warn "Dry-run mode — nothing will be written"

# ── Special cases (non-standard target paths) ─────────────────────────────────

deploy_xsettingsd() {
    info "xsettingsd → ~/.config/xsettingsd/xsettingsd.conf"
    run mkdir -p "$HOME/.config/xsettingsd"
    run cp "$CONFIGS_DIR/xsettingsd/xsettingsd.conf" "$HOME/.config/xsettingsd/xsettingsd.conf"
}

deploy_scripts() {
    info "Scripts → ~/.config/Scripts/"
    run mkdir -p "$HOME/.config/Scripts"
    run cp -r "$CONFIGS_DIR/Scripts/." "$HOME/.config/Scripts/"
    if ! $DRY_RUN; then
        chmod +x "$HOME/.config/Scripts/"*.sh 2>/dev/null || true
    fi
}

deploy_gtk4() {
    info "gtk-4.0 → ~/.config/gtk-4.0/"
    run mkdir -p "$HOME/.config/gtk-4.0"
    run cp -r "$CONFIGS_DIR/gtk-4.0/." "$HOME/.config/gtk-4.0/"
}

# ── Standard deploys ──────────────────────────────────────────────────────────

STANDARD_CONFIGS=(
    bat
    btop
    cava
    fastfetch
    fish
    gtk-3.0
    kitty
    lazygit
    mako
    niri
    nvim
    rofi
    waybar
    wlogout
    yazi
)

for config in "${STANDARD_CONFIGS[@]}"; do
    src="$CONFIGS_DIR/$config"
    dst="$TARGET_DIR/$config"

    if [[ ! -d "$src" ]]; then
        warn "Missing: $config — skipped"
        continue
    fi

    info "$config → $dst"
    run mkdir -p "$dst"
    run cp -r "$src/." "$dst/"
    success "$config deployed"
done

# ── Special cases ─────────────────────────────────────────────────────────────

deploy_xsettingsd
deploy_scripts
deploy_gtk4

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
success "All done. Reload niri: \`niri msg action load-config-file\`"
$DRY_RUN && warn "Was dry-run — nothing actually written"
