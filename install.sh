#!/bin/bash
# install.sh — deploy dotfiles + install dependencies
# usage: bash install.sh [--dry-run] [--deps-only] [--deploy-only]
#
# packages: pacman + AUR (pikaur)

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

    # Portals / Wayland compat
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-utils
    qt5-wayland
    qt6-wayland

    # Polkit
    polkit
    polkit-gnome

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
    librewolf              # browser (Mod+B)
    telegram-desktop       # messaging (Mod+M)
    fractal                # Matrix client (Mod+F)
    localsend-bin          # local file sharing (Mod+Z)
    waypaper               # GUI wallpaper picker (swww)
    cmus                   # music player (Mod+X)
)

install_pikaur() {
    if command -v pikaur &>/dev/null; then
        success "pikaur already installed"
        return
    fi

    info "Installing pikaur..."
    run sudo pacman -S --needed --noconfirm base-devel git

    local tmp
    tmp=$(mktemp -d)
    run git clone https://aur.archlinux.org/pikaur.git "$tmp/pikaur"

    if ! $DRY_RUN; then
        (cd "$tmp/pikaur" && makepkg -si --noconfirm)
    else
        dry "cd $tmp/pikaur && makepkg -si --noconfirm"
    fi

    rm -rf "$tmp"
    success "pikaur installed"

    # Remove yay and paru if present
    for aur_helper in yay paru; do
        if command -v "$aur_helper" &>/dev/null; then
            warn "$aur_helper found — removing in favor of pikaur"
            run sudo pacman -Rns --noconfirm "$aur_helper" 2>/dev/null || \
                warn "Could not remove $aur_helper automatically — remove manually"
        fi
    done
}


# ── Hardware detection ────────────────────────────────────────────────────────

detect_hardware() {
    echo ""
    info "Detecting hardware..."

    # ── CPU microcode ─────────────────────────────────────────────────────────

    local cpu
    cpu=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')

    case "$cpu" in
        GenuineIntel)
            info "Intel CPU detected → installing intel-ucode"
            run sudo pacman -S --needed --noconfirm intel-ucode
            ;;
        AuthenticAMD)
            info "AMD CPU detected → installing amd-ucode"
            run sudo pacman -S --needed --noconfirm amd-ucode
            ;;
        *)
            warn "Unknown CPU vendor: $cpu — skipping microcode"
            ;;
    esac

    # ── GPU drivers + video acceleration ──────────────────────────────────────

    local gpu_intel gpu_amd gpu_nvidia
    gpu_intel=$(lspci 2>/dev/null | grep -i "VGA\|3D\|Display" | grep -i intel || true)
    gpu_amd=$(lspci 2>/dev/null | grep -i "VGA\|3D\|Display" | grep -i "amd\|radeon\|amdgpu" || true)
    gpu_nvidia=$(lspci 2>/dev/null | grep -i "VGA\|3D\|Display" | grep -i nvidia || true)

    if [[ -n "$gpu_intel" ]]; then
        info "Intel GPU detected → installing drivers + VA-API"
        run sudo pacman -S --needed --noconfirm \
            mesa \
            vulkan-intel \
            intel-media-driver \
            libva-intel-driver \
            libva-utils
        success "Intel GPU drivers installed"
    fi

    if [[ -n "$gpu_amd" ]]; then
        info "AMD GPU detected → installing drivers + VA-API"
        run sudo pacman -S --needed --noconfirm \
            mesa \
            vulkan-radeon \
            libva-mesa-driver \
            mesa-vdpau \
            libva-utils
        success "AMD GPU drivers installed"
    fi

    if [[ -n "$gpu_nvidia" ]]; then
        info "Nvidia GPU detected → installing drivers + NVENC"
        run sudo pacman -S --needed --noconfirm \
            nvidia-dkms \
            nvidia-utils \
            nvidia-settings \
            libva-nvidia-driver \
            cuda
        # nvidia-vaapi-driver for VA-API support
        run pikaur -S --needed --noconfirm nvidia-vaapi-driver
        success "Nvidia GPU drivers installed"
        warn "Reboot required after Nvidia driver install"
    fi

    if [[ -z "$gpu_intel" && -z "$gpu_amd" && -z "$gpu_nvidia" ]]; then
        warn "No known GPU detected — skipping GPU drivers"
    fi

    # ── Hybrid Intel+Nvidia (laptop) ──────────────────────────────────────────

    if [[ -n "$gpu_intel" && -n "$gpu_nvidia" ]]; then
        info "Hybrid Intel+Nvidia detected → installing optimus-manager"
        run pikaur -S --needed --noconfirm optimus-manager
        warn "Configure optimus-manager after reboot"
    fi

    success "Hardware detection done"
}


# ── CachyOS setup ─────────────────────────────────────────────────────────────

setup_cachyos() {
    echo ""
    info "Setting up CachyOS..."

    # ── Repos ─────────────────────────────────────────────────────────────────

    if grep -q "\[cachyos\]" /etc/pacman.conf 2>/dev/null; then
        success "CachyOS repos already configured"
    else
        info "Adding CachyOS repositories..."

        # Detect CPU instruction set support (v4 > v3 > baseline)
        local cpu_level="baseline"
        if grep -q "avx512" /proc/cpuinfo 2>/dev/null; then
            cpu_level="v4"
        elif grep -q "avx2" /proc/cpuinfo 2>/dev/null; then
            cpu_level="v3"
        fi
        info "CPU level detected: $cpu_level"

        run pikaur -S --needed --noconfirm cachyos-keyring cachyos-mirrorlist

        if ! $DRY_RUN; then
            if [[ "$cpu_level" == "v4" ]]; then
                pikaur -S --needed --noconfirm cachyos-v4-mirrorlist
                sudo tee -a /etc/pacman.conf > /dev/null << 'PACMAN'

[cachyos-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-v4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
PACMAN

            elif [[ "$cpu_level" == "v3" ]]; then
                pikaur -S --needed --noconfirm cachyos-v3-mirrorlist
                sudo tee -a /etc/pacman.conf > /dev/null << 'PACMAN'

[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
PACMAN

            else
                sudo tee -a /etc/pacman.conf > /dev/null << 'PACMAN'

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
PACMAN
            fi

            sudo pacman -Sy
        else
            dry "append CachyOS $cpu_level repos to /etc/pacman.conf"
        fi
        success "CachyOS repos configured ($cpu_level)"
    fi

    # ── Packages ──────────────────────────────────────────────────────────────

    info "Installing CachyOS packages..."
    run sudo pacman -S --needed --noconfirm \
        cachyos-settings \
        ananicy-cpp \
        bpftune \
        cachyos-ananicy-rules \
        scx-scheds
    success "CachyOS packages installed"

    # ── Services ──────────────────────────────────────────────────────────────

    info "Enabling CachyOS services..."

    local services=(
        ananicy-cpp      # process priority daemon
        bpftune          # auto kernel tuning
        systemd-oomd     # out-of-memory daemon
        bluetooth        # bluetooth
        NetworkManager   # network
        fstrim.timer     # SSD trim
        systemd-timesyncd # NTP time sync
    )

    for svc in "${services[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            success "$svc already enabled"
        else
            run sudo systemctl enable --now "$svc"
            success "$svc enabled"
        fi
    done

    # ── Kernel scheduler (scx_bpfland) ───────────────────────────────────────

    info "Configuring scx scheduler (bpfland)..."
    if ! $DRY_RUN; then
        sudo mkdir -p /etc/scx

        # Create scx_loader service if it doesn't exist
        sudo tee /etc/systemd/system/scx_loader.service > /dev/null << 'SYSTEMD'
[Unit]
Description=SCX Scheduler Loader (scx_bpfland)
After=sysinit.target

[Service]
Type=simple
ExecStart=/usr/bin/scx_bpfland
Restart=on-failure

[Install]
WantedBy=multi-user.target
SYSTEMD

        sudo systemctl daemon-reload
        sudo systemctl enable scx_loader
    else
        dry "create and enable scx_loader.service"
    fi
    success "scx_bpfland scheduler configured"

    # ── Profile sync daemon ───────────────────────────────────────────────────

    info "Installing profile-sync-daemon..."
    run sudo pacman -S --needed --noconfirm profile-sync-daemon
    run systemctl --user enable --now psd
    success "profile-sync-daemon enabled"

    success "CachyOS setup done"
}


# ── SELinux setup ─────────────────────────────────────────────────────────────

setup_selinux() {
    echo ""
    info "Setting up SELinux..."

    # ── Packages ──────────────────────────────────────────────────────────────

    # ── GPG keys for SELinux packages ────────────────────────────────────────

    info "Importing SELinux GPG keys..."
    run gpg --keyserver keyserver.ubuntu.com --recv-keys 2BBED9CB1A68EF55
    success "GPG keys imported"

    info "Installing SELinux packages..."
    run sudo pacman -S --needed --noconfirm \
        audit

    run pikaur -S --needed --noconfirm \
        libselinux \
        libsemanage \
        libsepol \
        policycoreutils \
        checkpolicy \
        setools \
        selinux-refpolicy-arch-git

    success "SELinux packages installed"

    # ── Bootloader (kernel params) ────────────────────────────────────────────

    info "Configuring kernel parameters for SELinux..."
    if ! $DRY_RUN; then
        local cmdline="/etc/kernel/cmdline"
        if [[ -f "$cmdline" ]]; then
            if ! grep -q "security=selinux" "$cmdline"; then
                sudo sed -i 's/$/ security=selinux selinux=1 enforcing=0/' "$cmdline"
                success "Kernel cmdline updated"
            else
                success "SELinux kernel params already set"
            fi
        else
            warn "$cmdline not found — add manually: security=selinux selinux=1 enforcing=0"
        fi
    else
        dry "append security=selinux selinux=1 enforcing=0 to /etc/kernel/cmdline"
    fi

    # ── PAM ───────────────────────────────────────────────────────────────────
    # pam_selinux.so only available after reboot with SELinux active
    # configured post-reboot automatically via a oneshot service

    info "Creating post-reboot PAM configurator..."
    if ! $DRY_RUN; then
        sudo tee /etc/systemd/system/selinux-pam-setup.service > /dev/null << 'SYSTEMD'
[Unit]
Description=Configure PAM for SELinux (runs once after SELinux is active)
After=local-fs.target
ConditionPathExists=!/etc/selinux/.pam-configured

[Service]
Type=oneshot
ExecStart=/bin/bash -c "grep -q pam_selinux /etc/pam.d/login || echo session required pam_selinux.so >> /etc/pam.d/login && touch /etc/selinux/.pam-configured"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SYSTEMD
        sudo systemctl daemon-reload
        sudo systemctl enable selinux-pam-setup
    else
        dry "create selinux-pam-setup.service"
    fi

    # ── Services ──────────────────────────────────────────────────────────────

    info "Enabling audit daemon..."
    run sudo systemctl enable --now auditd
    success "auditd enabled"

    # ── Mode: permissive ──────────────────────────────────────────────────────

    info "Setting SELinux to permissive mode..."
    if ! $DRY_RUN; then
        sudo mkdir -p /etc/selinux
        sudo tee /etc/selinux/config > /dev/null << 'SELINUX'
# SELinux configuration
# permissive = log only, no blocking (safe for initial setup)
# enforcing  = full enforcement (switch after audit2allow review)
SELINUXTYPE=refpolicy
SELINUX=permissive
SELINUX
    else
        dry "write /etc/selinux/config (permissive)"
    fi

    success "SELinux configured in permissive mode"
    warn "Reboot required to activate SELinux"
    warn "After reboot, check logs: journalctl -t setroubleshoot"
    warn "When ready to enforce: setenforce 1 && sed -i 's/permissive/enforcing/' /etc/selinux/config"
}

install_deps() {
    install_pikaur
    setup_cachyos
    detect_hardware
    setup_selinux

    info "Installing pacman packages..."
    run sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
    success "Pacman packages installed"

    info "Installing AUR packages..."
    run pikaur -S --needed --noconfirm "${AUR_PKGS[@]}"
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
