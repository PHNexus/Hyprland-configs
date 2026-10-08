#!/bin/bash

set -euo pipefail

REPO_DIR="$HOME/Documents/GitHub/Hyprland-configs"
CONFIG_DIR="$REPO_DIR/configs"

CONFIG_FOLDERS=(
    "btop"
    "nvim"
    "cava"
    "fastfetch"
    "fish"
    "hypr"
    "kitty"
    "quickshell"
    "swaync"
    "waybar"
    "gtk-3.0"
    "gtk-4.0"
    "wlogout"
    "wofi"
    "xdg-desktop-portal"
    "dock-bar"
)

msg()  { echo -e "\033[1;34m[INFO]\033[0m $1"; }
ok()   { echo -e "\033[1;32m[ OK ]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
err()  { echo -e "\033[1;31m[ERR ]\033[0m $1"; exit 1; }

shopt -s nullglob

[[ -d "$REPO_DIR" ]] || err "Directory $REPO_DIR not found."

cd "$REPO_DIR" || err "Cannot access $REPO_DIR."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || err "Not a valid Git repository."

msg "Starting sync..."

# Wallpapers
if [[ -d "$HOME/Pictures/Wallpapers" ]]; then
    mkdir -p "$REPO_DIR/Wallpapers"

    rsync -a --delete \
        "$HOME/Pictures/Wallpapers/" \
        "$REPO_DIR/Wallpapers/"

    ok "Wallpapers synced"
else
    warn "Wallpapers folder not found"
fi

# Dock-bar
if [[ -d "$HOME/.local/share/dock-bar" ]]; then
    mkdir -p "$REPO_DIR/dock-bar"

    rsync -a --delete \
        --exclude=".git" \
        "$HOME/.local/share/dock-bar/" \
        "$REPO_DIR/dock-bar/"

    ok "Dock-bar synced"
else
    warn "Dock-bar folder not found"
fi

# Configs
msg "Copying configs..."

for folder in "${CONFIG_FOLDERS[@]}"; do
    if [[ -d "$HOME/.config/$folder" ]]; then
        mkdir -p "$CONFIG_DIR/$folder"

        rsync -a --delete \
            "$HOME/.config/$folder/" \
            "$CONFIG_DIR/$folder/"

        ok "Config: $folder"
    else
        warn "Folder not found: $folder"
    fi
done

mkdir -p "$CONFIG_DIR"

# starship.toml
if [[ -f "$HOME/.config/starship.toml" ]]; then
    cp -fL "$HOME/.config/starship.toml" "$CONFIG_DIR/"
    ok "File: starship.toml"
else
    warn "File not found: starship.toml"
fi

# .gtkrc-2.0
if [[ -f "$HOME/.gtkrc-2.0" ]]; then
    cp -fL "$HOME/.gtkrc-2.0" "$CONFIG_DIR/"
    ok "File: .gtkrc-2.0"
else
    warn "File not found: .gtkrc-2.0"
fi

# Date
DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H:%M:%S')

msg "Checking for changes..."

# Nothing changed
if git diff --quiet \
    && git diff --cached --quiet \
    && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then

    warn "No changes to commit."
    ok "Sync complete."
    exit 0
fi

# Show exactly what changed
msg "Changes detected:"
git status --short

echo

git diff --stat

echo

# Stage only actual changes
git add -A

# Check staged diff
if git diff --cached --quiet; then
    warn "No changes staged."
    ok "Sync complete."
    exit 0
fi

# Commit only the diff
COMMIT_MESSAGE="update: configs - $DATE $TIME"

git commit -m "$COMMIT_MESSAGE"

ok "Commit created: $COMMIT_MESSAGE"

# Pull remote changes before push
msg "Updating from GitHub..."

if git pull --rebase origin main 2>/dev/null; then
    msg "Pushing to GitHub..."

    if git push origin main; then
        ok "Push successful."
    else
        err "Push failed."
    fi
else
    git rebase --abort 2>/dev/null || true
    err "Pull/rebase failed."
fi

ok "Sync complete."