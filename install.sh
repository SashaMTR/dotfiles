#!/bin/bash
# install.sh — deploy dotfiles + install dependencies
# usage: bash install.sh [--dry-run] [--deps-only] [--deploy-only]
#
# packages: pacman + AUR (yay)

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CONFIGS_DIR="$DOTFILES_DIR/Configs"
TARGET_DIR="$HOME/.config"
DRY_RUN=false
DEPS_ONLY=false
DEPLOY_ONLY=false

# ── Args ──────────────────────────────────────────────────────────────────────

for arg in "$@"; do
    case "$arg" in
        --dry-run)     DRY_RUN=true ;;
        --deps-only)   DEPS_ONLY=true ;;
        --deploy-only) DEPLOY_ONLY=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────

info()    { echo -e "\e[34m  ➤\e[0m  $*"; }
success() { echo -e "\e[32m  ✔\e[0m  $*"; }
warn()    { echo -e "\e[33m  ⚠\e[0m  $*"; }
dry()     { echo -e "\e[90m  ~\e[0m  [dry] $*"; }

run() {
    if $DRY_RUN; then dry "$*"
    else "$@"
    fi
}

# ── Dependencies ──────────────────────────────────────────────────────────────

# Pacman packages
PACMAN_PKGS=(
    # WM / Wayland
    xwayland-satellite     # XWayland support for niri
    xsettingsd             # GTK settings daemon for Wayland

    # Terminal / Shell
    kitty
    fish
    zoxide                 # smart cd
    eza                    # modern ls

    # Editor
    neovim

    # Bar / Notifications
    waybar
    mako
    python-gobject         # required by some waybar modules

    # Launcher / Clipboard
    rofi-wayland
    wl-clipboard
    cliphist

    # Wallpaper / Lock / Idle
    hyprlock
    swayidle

    # Screenshot
    grim
    slurp

    # Audio
    pipewire
    pipewire-pulse
    wireplumber
    playerctl
    pulsemixer

    # Brightness
    brightnessctl

    # Network
    networkmanager
    nm-connection-editor

    # Bluetooth
    bluez
    bluez-utils

    # File manager
    yazi
    unarchiver             # archive extraction for yazi
    ffmpegthumbnailer      # video thumbnails for yazi
    imagemagick            # image processing

    # Git
    lazygit
    git-delta              # diff pager for lazygit

    # System tools
    btop
    fastfetch
    bat
    cava
    wlogout
    mako

    # KDE Connect
    kdeconnect

    # SSH / Keyring
    lxqt-openssh-askpass
    gnome-keyring

    # Fonts
    ttf-nerd-fonts-symbols # icons fallback (NF)
    noto-fonts             # unicode fallback
    noto-fonts-emoji       # emoji
)

# AUR packages
AUR_PKGS=(
    niri-git               # niri WM (latest git)
    swww                   # animated wallpaper daemon
    bluetui                # bluetooth TUI
    ttf-google-sans        # Google Sans Flex (waybar/rofi font)
    ncdu                   # disk usage TUI (yazi on-click)
)

install_deps() {
    info "Installing pacman packages..."
    run sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
    success "Pacman packages installed"

    if ! command -v yay &>/dev/null; then
        warn "yay not found — skipping AUR packages"
        warn "Install yay manually then re-run with --deps-only"
        return
    fi

    info "Installing AUR packages..."
    run yay -S --needed --noconfirm "${AUR_PKGS[@]}"
    success "AUR packages installed"
}

# ── Deploy helpers ────────────────────────────────────────────────────────────

deploy_xsettingsd() {
    info "xsettingsd → ~/.config/xsettingsd/xsettingsd.conf"
    run mkdir -p "$HOME/.config/xsettingsd"
    run cp "$CONFIGS_DIR/xsettingsd/xsettingsd.conf" "$HOME/.config/xsettingsd/xsettingsd.conf"
    success "xsettingsd deployed"
}

deploy_scripts() {
    info "Scripts → ~/.config/Scripts/"
    run mkdir -p "$HOME/.config/Scripts"
    run cp -r "$CONFIGS_DIR/Scripts/." "$HOME/.config/Scripts/"
    if ! $DRY_RUN; then
        chmod +x "$HOME/.config/Scripts/"*.sh 2>/dev/null || true
    fi
    success "Scripts deployed"
}

deploy_gtk4() {
    info "gtk-4.0 → ~/.config/gtk-4.0/"
    run mkdir -p "$HOME/.config/gtk-4.0"
    run cp -r "$CONFIGS_DIR/gtk-4.0/." "$HOME/.config/gtk-4.0/"
    success "gtk-4.0 deployed"
}

deploy_configs() {
    if [[ ! -d "$CONFIGS_DIR" ]]; then
        echo "Error: '$CONFIGS_DIR' not found"
        exit 1
    fi

    $DRY_RUN && warn "Dry-run mode — nothing will be written"

    local STANDARD_CONFIGS=(
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
        local src="$CONFIGS_DIR/$config"
        local dst="$TARGET_DIR/$config"

        if [[ ! -d "$src" ]]; then
            warn "Missing: $config — skipped"
            continue
        fi

        info "$config → $dst"
        run mkdir -p "$dst"
        run cp -r "$src/." "$dst/"
        success "$config deployed"
    done

    deploy_xsettingsd
    deploy_scripts
    deploy_gtk4
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo ""
echo -e "\e[1m  ZeruxFR31 dotfiles installer\e[0m"
echo ""

if $DEPS_ONLY; then
    install_deps
elif $DEPLOY_ONLY; then
    deploy_configs
else
    install_deps
    echo ""
    deploy_configs
fi

echo ""
success "All done."
echo -e "  Reload niri:  \e[90mniri msg action load-config-file\e[0m"
echo -e "  Set fish:     \e[90mchsh -s \$(which fish)\e[0m"
echo -e "  Enable BT:    \e[90msudo systemctl enable --now bluetooth\e[0m"
echo -e "  Enable KDC:   \e[90msudo systemctl enable --now kdeconnect\e[0m"
$DRY_RUN && warn "Was dry-run — nothing actually written"
