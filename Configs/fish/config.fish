set -g fish_greeting ""

# ── Basic ─────────────────────────────────────────────────────────────────────

alias c    = 'clear'
alias n    = 'nvim'
alias ff   = 'fastfetch'
alias gc   = 'git clone'
alias ls   = 'eza -1h -s modified -r --icons=always --group-directories-first'
alias reload = 'source ~/.config/fish/config.fish ; kitty @ load-config'
alias bip  = 'pacman -Qqe > ~/dotfiles/installed-pkg/pkglist.txt && notify-send "Backup" "Package list saved" && echo "Saved: ~/dotfiles/installed-pkg/pkglist.txt"'

# ── Navigation ────────────────────────────────────────────────────────────────

alias b = 'cd ..'
alias h = 'cd'
alias d = 'cd ~/Downloads'

# ── Arch ──────────────────────────────────────────────────────────────────────

alias pacup = 'sudo timeshift --create --comments "Before update" --tags O && yay -Syu'
alias paci  = 'yay -S --needed'
alias pacr  = 'yay -Rns'

# ── System ────────────────────────────────────────────────────────────────────

alias ts       = 'sudo timeshift --create --comments "Manual" --tags O'
alias tsd      = 'sudo timeshift --delete-all'
alias tsl      = 'sudo timeshift --list'
alias timeshift = 'sudo timeshift-gtk'
alias gparted  = 'sudo -E gparted'

# ── Power ─────────────────────────────────────────────────────────────────────

alias logout  = 'loginctl terminate-user $USER'
alias reboot  = 'systemctl reboot'
alias off     = 'systemctl poweroff'
alias suspend = 'systemctl suspend ; bash ~/.config/Scripts/lockscreen.sh'

# ── Network ───────────────────────────────────────────────────────────────────

alias pingg = 'ping -c 5 archlinux.org'
alias wifi  = 'nmtui'
alias bt    = 'bluetui'

# ── Zoxide ────────────────────────────────────────────────────────────────────

zoxide init fish | source
