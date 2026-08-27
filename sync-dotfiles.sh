#!/bin/bash
set -euo pipefail

REPO_DIR="$HOME/Documents/GitHub/Hyprland-configs"
CONFIG_DIR="$REPO_DIR/configs"

CONFIG_FOLDERS=(
    "btop" "nvim" "cava" "fastfetch" "fish"
    "hypr" "kitty" "quickshell" "swaync" "waybar" "wofi"
    "xdg-desktop-portal"
)

msg()  { echo -e "\033[1;34m[INFO]\033[0m $1"; }
ok()   { echo -e "\033[1;32m[ OK ]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
err()  { echo -e "\033[1;31m[ERR ]\033[0m $1"; exit 1; }

shopt -s nullglob

[[ -d "$REPO_DIR" ]] || err "Directory $REPO_DIR not found."
cd "$REPO_DIR" || err "Cannot access $REPO_DIR."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || err "Not a valid Git repository."

msg "Starting sync..."

# Wallpapers
if [[ -d "$HOME/Pictures/Wallpapers" ]]; then
    mkdir -p "$REPO_DIR/wallpapers"
    rsync -a --delete "$HOME/Pictures/Wallpapers/" "$REPO_DIR/wallpapers/"
    ok "Wallpapers synced"
else
    warn "Wallpapers folder not found"
fi

# Config folders
msg "Copying configs..."
for folder in "${CONFIG_FOLDERS[@]}"; do
    if [[ -d "$HOME/.config/$folder" ]]; then
        mkdir -p "$CONFIG_DIR/$folder"
        if [[ -n "$(ls -A "$HOME/.config/$folder" 2>/dev/null)" ]]; then
            rsync -a --delete "$HOME/.config/$folder/" "$CONFIG_DIR/$folder/"
        else
            rsync -a "$HOME/.config/$folder/" "$CONFIG_DIR/$folder/"
        fi
        ok "Config: $folder"
    else
        warn "Folder not found: $folder"
    fi
done

# Individual config files
mkdir -p "$CONFIG_DIR"

if [[ -f "$HOME/.config/starship.toml" ]]; then
    cp -fL "$HOME/.config/starship.toml" "$CONFIG_DIR/"
    ok "File: starship.toml"
else
    warn "File not found: starship.toml"
fi

# Git sync
msg "Pushing to GitHub..."
if git diff --quiet && git diff --cached --quiet; then
    if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        git add .
        git commit -m "Sync: new files - $(date '+%Y-%m-%d %H:%M')"
    else
        warn "No changes to commit."
        ok "Sync complete."
        exit 0
    fi
else
    git add .
    git commit -m "Sync: $(date '+%Y-%m-%d %H:%M')" || warn "Empty commit."
fi

if git pull --rebase origin main 2>/dev/null; then
    git push origin main && ok "Push successful."
else
    git rebase --abort 2>/dev/null || true
    err "Pull/push failed."
fi

ok "Sync complete."