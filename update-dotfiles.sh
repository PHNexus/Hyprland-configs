#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$HOME/Documents/GitHub/Hyprland-configs"
CONFIG_DIR="$REPO_DIR/configs"
WALLPAPER_SOURCE="$HOME/Pictures/Wallpapers"
DOCKBAR_SOURCE="$HOME/.local/share/dock-bar"
MAX_NEW_DOCKBAR_ASSET_SIZE_MB=5

CONFIG_FOLDERS=(
    "btop" "nvim" "cava" "fastfetch" "fish" "hypr" "kitty"
    "quickshell" "swaync" "waybar" "gtk-3.0" "gtk-4.0"
    "wlogout" "wofi" "xdg-desktop-portal" "dock-bar"
)

msg()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$1"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[ERR ]\033[0m %s\n' "$1" >&2; exit 1; }

[[ -d "$REPO_DIR" ]] || err "Repository directory not found: $REPO_DIR"
cd "$REPO_DIR" || err "Cannot access repository directory."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || err "Not a valid Git repository."

# Avoid accidentally including unrelated changes that were staged before this script ran.
if ! git diff --cached --quiet; then
    err "You already have staged changes. Commit or unstage them before running this script."
fi

msg "Starting sync..."
mkdir -p "$CONFIG_DIR"

# Mirror wallpapers by content. All new wallpapers are retained and staged together.
if [[ -d "$WALLPAPER_SOURCE" ]]; then
    mkdir -p "$REPO_DIR/Wallpapers"
    rsync -a --checksum --delete -- "$WALLPAPER_SOURCE/" "$REPO_DIR/Wallpapers/"
    ok "Wallpapers synced"
else
    warn "Wallpapers folder not found: $WALLPAPER_SOURCE"
fi

# Mirror dock-bar, excluding its own Git metadata. New files above the size limit are skipped.
if [[ -d "$DOCKBAR_SOURCE" ]]; then
    mkdir -p "$REPO_DIR/dock-bar"
    rsync -a --checksum --delete --exclude='.git' -- "$DOCKBAR_SOURCE/" "$REPO_DIR/dock-bar/"
    ok "Dock-bar synced"
else
    warn "Dock-bar folder not found: $DOCKBAR_SOURCE"
fi

msg "Copying configs..."
for folder in "${CONFIG_FOLDERS[@]}"; do
    source="$HOME/.config/$folder"
    target="$CONFIG_DIR/$folder"
    if [[ -d "$source" ]]; then
        mkdir -p "$target"
        rsync -a --checksum --delete -- "$source/" "$target/"
        ok "Config: $folder"
    else
        warn "Folder not found: $folder"
    fi
done

if [[ -f "$HOME/.config/starship.toml" ]]; then
    cp -fL -- "$HOME/.config/starship.toml" "$CONFIG_DIR/starship.toml"
    ok "File: starship.toml"
else
    warn "File not found: starship.toml"
fi

if [[ -f "$HOME/.gtkrc-2.0" ]]; then
    cp -fL -- "$HOME/.gtkrc-2.0" "$CONFIG_DIR/.gtkrc-2.0"
    ok "File: .gtkrc-2.0"
else
    warn "File not found: .gtkrc-2.0"
fi

# Stage only paths managed by this script. Git reuses identical content objects,
# so unchanged files are not stored again in each commit.
managed_paths=()
for path in "configs" "Wallpapers" "dock-bar" "update-dotfiles.sh" "install.sh"; do
    [[ -e "$path" ]] && managed_paths+=("$path")
done

if ((${#managed_paths[@]} == 0)); then
    warn "No managed paths found."
    exit 0
fi

git add -A -- "${managed_paths[@]}"

# Unstage oversized NEW dock-bar files only; tracked files and wallpapers are unaffected.
max_bytes=$((MAX_NEW_DOCKBAR_ASSET_SIZE_MB * 1024 * 1024))
if [[ -d "$REPO_DIR/dock-bar" ]]; then
    while IFS= read -r -d '' file; do
        [[ -f "$file" ]] || continue
        if ! git ls-files --error-unmatch -- "$file" >/dev/null 2>&1; then
            size_bytes=$(stat -c '%s' -- "$file")
            if ((size_bytes > max_bytes)); then
                git reset -q -- "$file"
                warn "Skipping new dock-bar file larger than ${MAX_NEW_DOCKBAR_ASSET_SIZE_MB} MiB: $file"
            fi
        fi
    done < <(find "$REPO_DIR/dock-bar" -type f -not -path '*/.git/*' -print0)
fi

if git diff --cached --quiet; then
    warn "No new changes to commit."
else
    msg "Changes to be committed:"
    git diff --cached --name-status
    echo
    git diff --cached --stat
    echo

    DATE=$(date '+%Y-%m-%d')
    TIME=$(date '+%H:%M:%S')
    COMMIT_MESSAGE="update: configs - $DATE $TIME"
    git commit -m "$COMMIT_MESSAGE"
    ok "Commit created: $COMMIT_MESSAGE"
fi

# Always sync and push, even when this run creates no new commit.
# --autostash protects unrelated tracked edits from blocking the rebase.
msg "Updating from GitHub..."
if git pull --rebase --autostash origin main; then
    msg "Pushing to GitHub..."
    git push origin main || err "Push failed."
else
    err "Pull/rebase failed. Review the Git output above; local changes were preserved where possible."
fi

ok "Sync complete."
