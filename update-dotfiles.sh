#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$HOME/Documents/GitHub/Hyprland-configs"
CONFIG_DIR="$REPO_DIR/configs"
WALLPAPER_SOURCE="$HOME/Pictures/Wallpapers"
DOCKBAR_SOURCE="$HOME/.local/share/dock-bar"
LOCAL_BIN_SOURCE="$HOME/.local/bin"
LOCAL_BIN_TARGET="$REPO_DIR/local/bin"
MAX_NEW_DOCKBAR_ASSET_SIZE_MB=5

LOCAL_BIN_FILES=(
    "dock-bar"
    "hyprquickpaper"
    "settings"
)

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
    "wlogout"
    "wofi"
    "xdg-desktop-portal"
    "dock-bar"
    "Thunar"
)

msg() {
    printf '\033[1;34m[INFO]\033[0m %s\n' "$1"
}

ok() {
    printf '\033[1;32m[ OK ]\033[0m %s\n' "$1"
}

warn() {
    printf '\033[1;33m[WARN]\033[0m %s\n' "$1"
}

err() {
    printf '\033[1;31m[ERR ]\033[0m %s\n' "$1" >&2
    exit 1
}

# Validate repository.
[[ -d "$REPO_DIR" ]] || err "Repository directory not found: $REPO_DIR"

cd "$REPO_DIR" || err "Cannot access repository directory."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || err "Not a valid Git repository."

# Avoid accidentally including unrelated changes staged before this script.
if ! git diff --cached --quiet; then
    err "You already have staged changes. Commit or unstage them before running this script."
fi

msg "Starting sync..."

mkdir -p "$CONFIG_DIR"

# Mirror wallpapers.
if [[ -d "$WALLPAPER_SOURCE" ]]; then
    mkdir -p "$REPO_DIR/Wallpapers"

    rsync -a --checksum --delete -- \
        "$WALLPAPER_SOURCE/" \
        "$REPO_DIR/Wallpapers/"

    ok "Wallpapers synced"
else
    warn "Wallpapers folder not found: $WALLPAPER_SOURCE"
fi

# Mirror dock-bar, excluding its own Git metadata.
if [[ -d "$DOCKBAR_SOURCE" ]]; then
    mkdir -p "$REPO_DIR/dock-bar"

    rsync -a --checksum --delete \
        --exclude='.git' \
        -- "$DOCKBAR_SOURCE/" "$REPO_DIR/dock-bar/"

    ok "Dock-bar synced"
else
    warn "Dock-bar folder not found: $DOCKBAR_SOURCE"
fi

# Sync only the selected executables from ~/.local/bin.
# Dereference symlinks so the repository contains the actual script contents,
# not links pointing to machine-specific paths.
mkdir -p "$LOCAL_BIN_TARGET"

for file in "${LOCAL_BIN_FILES[@]}"; do
    source="$LOCAL_BIN_SOURCE/$file"
    target="$LOCAL_BIN_TARGET/$file"

    if [[ -e "$source" ]]; then
        rsync -aL --checksum -- "$source" "$target"
        ok "Local bin: $file"
    else
        warn "File not found: $source"
    fi
done

# Sync configuration directories.
msg "Copying configs..."

for folder in "${CONFIG_FOLDERS[@]}"; do
    source="$HOME/.config/$folder"
    target="$CONFIG_DIR/$folder"

    if [[ -d "$source" ]]; then
        mkdir -p "$target"

        rsync -a --checksum --delete -- \
            "$source/" \
            "$target/"

        ok "Config: $folder"
    else
        warn "Folder not found: $folder"
    fi
done

# Sync individual configuration files.
# These files are stored directly inside the repository's configs directory.
CONFIG_FILES=(
    "starship.toml"
    "mimeapps.list"
)

for file in "${CONFIG_FILES[@]}"; do
    source="$HOME/.config/$file"
    target="$CONFIG_DIR/$file"

    if [[ -f "$source" ]]; then
        cp -fL -- "$source" "$target"
        ok "File: $file"
    else
        warn "File not found: $source"
    fi
done

# Check local AI installer.
LOCAL_AI_INSTALLER="$REPO_DIR/install-ai-local-1660TI+.sh"

if [[ -f "$LOCAL_AI_INSTALLER" ]]; then
    ok "File: install-ai-local-1660TI+.sh"
else
    warn "File not found: $LOCAL_AI_INSTALLER"
fi

# Check package list.
PACKAGES="$REPO_DIR/packages.txt"

if [[ -f "$PACKAGES" ]]; then
    ok "File: packages.txt"
else
    warn "File not found: $PACKAGES"
fi

# Stage only paths managed by this script.
managed_paths=(
    "configs"
    "Wallpapers"
    "dock-bar"
    "local/bin/dock-bar"
    "local/bin/hyprquickpaper"
    "local/bin/settings"
    "update-dotfiles.sh"
    "install.sh"
    "install-ai-local-1660TI+.sh"
    "packages.txt"
)

existing_paths=()

for path in "${managed_paths[@]}"; do
    if [[ -e "$path" ]]; then
        existing_paths+=("$path")
    fi
done

if ((${#existing_paths[@]} == 0)); then
    warn "No managed paths found."
    exit 0
fi

git add -A -- "${existing_paths[@]}"

# Unstage oversized NEW dock-bar files only.
# Files already present in HEAD and wallpapers are unaffected.
max_bytes=$((MAX_NEW_DOCKBAR_ASSET_SIZE_MB * 1024 * 1024))

if [[ -d "$REPO_DIR/dock-bar" ]]; then
    while IFS= read -r -d '' file; do
        [[ -f "$file" ]] || continue

        # Convert absolute file path to a repository-relative path.
        relpath="${file#"$REPO_DIR"/}"

        # Test whether the file exists in the current HEAD commit,
        # rather than checking the index after git add.
        if ! git cat-file -e "HEAD:$relpath" 2>/dev/null; then
            size_bytes=$(stat -c '%s' -- "$file")

            if ((size_bytes > max_bytes)); then
                git reset -q -- "$relpath"

                warn "Skipping new dock-bar file larger than ${MAX_NEW_DOCKBAR_ASSET_SIZE_MB} MiB: $relpath"
            fi
        fi
    done < <(
        find "$REPO_DIR/dock-bar" \
            -type f \
            -not -path '*/.git/*' \
            -print0
    )
fi

# Create a commit only when there are staged changes.
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

    # Count additions + deletions in staged changes.
    total_lines=$(
        git diff --cached --numstat |
            awk '{
                if ($1 != "-") add += $1;
                if ($2 != "-") del += $2;
            } END {
                print add + del
            }'
    )

    total_lines=${total_lines:-0}

    # <= 15 changed lines: "update"
    # > 15 changed lines: "update configs - DATE TIME"
    if ((total_lines <= 15)); then
        COMMIT_MESSAGE="update"
    else
        COMMIT_MESSAGE="update configs - $DATE $TIME"
    fi

    git commit -m "$COMMIT_MESSAGE"

    ok "Commit created: $COMMIT_MESSAGE"
fi

# Always pull and push, even if no new commit was created.
msg "Updating from GitHub..."

if git pull --rebase --autostash origin main; then
    msg "Pushing to GitHub..."

    git push origin main || err "Push failed."
else
    err "Pull/rebase failed. Review the Git output above; local changes were preserved where possible."
fi

ok "Sync complete."