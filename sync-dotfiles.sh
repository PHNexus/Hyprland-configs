#!/bin/bash
set -euo pipefail

# Configuração do repositório
REPO_DIR="$HOME/Documents/GitHub/Hyprland-configs"
CONFIG_DIR="$REPO_DIR/configs"
SCRIPTS_DIR="$REPO_DIR/bin"

# Pastas do .config que serão sincronizadas
CONFIG_FOLDERS=(
    "btop" "cava" "fastfetch" "gtk-3.0" "gtk-4.0"
    "hypr" "kitty" "swaync" "waybar" "wofi"
    "xdg-desktop-portal" "xfce4"
)

# Cores e funções de logging
msg()  { echo -e "\033[1;34m[INFO]\033[0m $1"; }
ok()   { echo -e "\033[1;32m[ OK ]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
err()  { echo -e "\033[1;31m[ERR ]\033[0m $1"; exit 1; }

# Configurações do shell
shopt -s nullglob

# Verificações iniciais
[[ -d "$REPO_DIR" ]] || err "Directory $REPO_DIR not found."
cd "$REPO_DIR" || err "Cannot access $REPO_DIR."

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Not a valid Git repository."
fi

msg "Starting Hyprland dotfiles sync..."

# Sincronização de Wallpapers
if [[ -d "$HOME/.config/wallpapers" ]]; then
    mkdir -p "$REPO_DIR/wallpapers"
    rsync -a --delete "$HOME/.config/wallpapers/" "$REPO_DIR/wallpapers/"
    ok "Wallpapers: synced"
else
    warn "Wallpapers folder not found at ~/.config/wallpapers"
fi

# Sincronização de Temas
if [[ -d "$HOME/.themes" ]]; then
    mkdir -p "$REPO_DIR/.themes"
    rsync -a --delete "$HOME/.themes/" "$REPO_DIR/.themes/"
    ok "Themes: synced"
else
    warn "Themes folder not found at ~/.themes"
fi

# Sincronização de Ícones (tentando localizações comuns)
ICON_PATHS=(
    "$HOME/.icons"
    "$HOME/.local/share/icons"
    "/usr/share/icons"
)

ICONS_FOUND=false
for icon_path in "${ICON_PATHS[@]}"; do
    if [[ -d "$icon_path" ]] && [[ -n "$(ls -A "$icon_path" 2>/dev/null)" ]]; then
        mkdir -p "$REPO_DIR/.icons"
        rsync -a --delete "$icon_path/" "$REPO_DIR/.icons/"
        ok "Icons: synced from $icon_path"
        ICONS_FOUND=true
        break
    fi
done

if [[ "$ICONS_FOUND" == "false" ]]; then
    warn "No icons folder found in common locations"
fi

# Sincronização das pastas de configuração
msg "Copying configurations..."
for folder in "${CONFIG_FOLDERS[@]}"; do
    if [[ -d "$HOME/.config/$folder" ]]; then
        mkdir -p "$CONFIG_DIR/$folder"
        if [[ -n "$(ls -A "$HOME/.config/$folder" 2>/dev/null)" ]]; then
            rsync -a --delete "$HOME/.config/$folder/" "$CONFIG_DIR/$folder/"
            ok "Config: $folder"
        else
            warn "Folder $folder is empty, copying without --delete"
            rsync -a "$HOME/.config/$folder/" "$CONFIG_DIR/$folder/"
        fi
    else
        warn "Folder not found: $folder"
    fi
done

# Sincronização de scripts (opcional)
if [[ -d "$SCRIPTS_DIR" ]]; then
    msg "Updating scripts..."
    mkdir -p "$HOME/.local/bin"
    for script in "$SCRIPTS_DIR"/*; do
        [[ -f "$script" ]] || continue
        name="$(basename "$script")"
        if [[ -f "$HOME/.local/bin/$name" ]]; then
            cp -f "$HOME/.local/bin/$name" "$script"
            ok "Script: $name"
        else
            warn "Script not found in system: $name"
        fi
    done
fi

# Arquivos dotfiles da Home (opcional)
msg "Copying home dotfiles..."
for file in .bashrc .zshrc; do
    if [[ -f "$HOME/$file" ]]; then
        cp -f "$HOME/$file" "$REPO_DIR/"
        ok "File: $file"
    fi
done

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
    err "Pull/push failed. Rebase aborted. Check your connection."
fi

ok "Sync complete."