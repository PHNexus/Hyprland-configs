#!/usr/bin/env bash

set -euo pipefail

# ============================================
# Hyprland-configs Installer
# Arch Linux + Hyprland
# ============================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
PICTURES_DIR="$HOME/Pictures"

echo "Welcome to Hyprland-configs Installer!"
echo

# --------------------------------------------
# Check OS
# --------------------------------------------

if [[ ! -f /etc/arch-release ]]; then
    echo "This installer is designed for Arch Linux."
    exit 1
fi

echo "Arch Linux detected."

# --------------------------------------------
# Check sudo
# --------------------------------------------

if ! sudo -v; then
    echo "sudo access is required."
    exit 1
fi

# --------------------------------------------
# Ensure base-devel and an AUR helper (yay) exist
# --------------------------------------------

echo
echo "Ensuring base-devel and git are installed..."
sudo pacman -S --needed --noconfirm base-devel git

if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    echo "AUR helper not found. Installing yay automatically..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd "$REPO_DIR"
    rm -rf /tmp/yay
fi

# --------------------------------------------
# Dependencies from packages.txt
# --------------------------------------------

echo
echo "Installing Arch Linux dependencies from packages.txt..."

if [[ -f "$REPO_DIR/packages.txt" ]]; then
    packages_content=$(grep -Ev '^[[:space:]]*$' "$REPO_DIR/packages.txt")
    
    official_packages_raw=$(echo "$packages_content" | sed '/^#AUR/,$d' | grep -Ev '^[[:space:]]*#')
    aur_packages_raw=$(echo "$packages_content" | sed -n '/^#AUR/,$p' | grep -Ev '^[[:space:]]*#')
    
    mapfile -t official_packages < <(printf '%s\n' "$official_packages_raw" | grep -Ev '^[[:space:]]*$' || true)
    if [[ ${#official_packages[@]} -gt 0 ]]; then
        echo "Installing official packages via pacman..."
        sudo pacman -S --needed "${official_packages[@]}"
    fi
    
    mapfile -t aur_packages < <(printf '%s\n' "$aur_packages_raw" | grep -Ev '^[[:space:]]*$' || true)
    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        if command -v yay &>/dev/null; then
            echo "Installing AUR packages via yay..."
            yay -S --needed "${aur_packages[@]}"
        elif command -v paru &>/dev/null; then
            echo "Installing AUR packages via paru..."
            paru -S --needed "${aur_packages[@]}"
        else
            echo "Neither yay nor paru is installed, skipping AUR packages."
        fi
    fi
else
    echo "packages.txt not found in repository root."
fi

echo "Dependencies installation step finished."

# --------------------------------------------
# Backup existing configurations & Wallpapers
# --------------------------------------------

echo
echo "Checking for existing configurations and wallpapers..."

configs=(
    btop
    cava
    fastfetch
    fish
    hypr
    kitty
    quickshell
    swaync
    waybar
    wofi
    xdg-desktop-portal
)

existing_configs=()

for config in "${configs[@]}"; do
    if [[ -e "$CONFIG_DIR/$config" ]]; then
        existing_configs+=("$config")
    fi
done

if [[ -e "$HOME/.config/starship.toml" ]]; then
    existing_configs+=("starship.toml")
fi

if [[ -d "$PICTURES_DIR/Wallpapers" ]]; then
    existing_configs+=("Pictures/Wallpapers")
fi

if [[ ${#existing_configs[@]} -gt 0 ]]; then
    echo
    echo "The following existing configurations/folders will be replaced:"
    echo

    for config in "${existing_configs[@]}"; do
        if [[ "$config" == "Pictures/Wallpapers" ]]; then
            echo "  • ~/Pictures/Wallpapers"
        elif [[ "$config" == "starship.toml" ]]; then
            echo "  • ~/.config/starship.toml"
        else
            echo "  • ~/.config/$config"
        fi
    done

    echo
    read -rp "Would you like to back them up first? [Y/n]: " backup_choice
    backup_choice="${backup_choice:-Y}"

    if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
        BACKUP_DIR="$CONFIG_DIR/backup/hyprland-configs-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"

        echo
        echo "Creating backup..."

        for config in "${existing_configs[@]}"; do
            if [[ "$config" == "Pictures/Wallpapers" ]]; then
                if [[ -d "$PICTURES_DIR/Wallpapers" ]]; then
                    mkdir -p "$BACKUP_DIR/Pictures"
                    cp -r "$PICTURES_DIR/Wallpapers" "$BACKUP_DIR/Pictures/"
                    echo "  - Backed up Pictures/Wallpapers"
                fi
            elif [[ "$config" == "starship.toml" ]]; then
                if [[ -f "$CONFIG_DIR/starship.toml" ]]; then
                    cp "$CONFIG_DIR/starship.toml" "$BACKUP_DIR/"
                    echo "  - Backed up starship.toml"
                fi
            else
                if [[ -e "$CONFIG_DIR/$config" ]]; then
                    cp -r "$CONFIG_DIR/$config" "$BACKUP_DIR/"
                    echo "  - Backed up $config"
                fi
            fi
        done

        echo
        echo "Backup complete!"
        echo "Your backup is located at:"
        echo "   $BACKUP_DIR"
    else
        echo
        echo "Skipping backup."
    fi
else
    echo "  - No conflicting existing configurations found."
fi

# --------------------------------------------
# Install configurations & Wallpapers
# --------------------------------------------

echo
echo "Installing dotfiles configurations..."

mkdir -p "$CONFIG_DIR"

for config in "${configs[@]}"; do
    if [[ -d "$REPO_DIR/configs/$config" ]]; then
        rm -rf "$CONFIG_DIR/$config"
        cp -r "$REPO_DIR/configs/$config" "$CONFIG_DIR/"
        echo "  - Installed config: $config"
    fi
done

if [[ -f "$REPO_DIR/configs/starship.toml" ]]; then
    cp -f "$REPO_DIR/configs/starship.toml" "$CONFIG_DIR/"
    echo "  - Installed file: starship.toml"
fi

if [[ -d "$REPO_DIR/Wallpapers" ]]; then
    rm -rf "$PICTURES_DIR/Wallpapers"
    mkdir -p "$PICTURES_DIR/Wallpapers"
    cp -r "$REPO_DIR/Wallpapers/." "$PICTURES_DIR/Wallpapers/"
    echo "  - Installed Wallpapers to Pictures/Wallpapers"
fi

# --------------------------------------------
# Post-install: Adjust user and monitor configs
# --------------------------------------------

echo
echo "Applying post-installation adjustments..."

# Update user paths dynamically in hyprquickpaper config.json
HYPRQUICKPAPER_CONFIG="$CONFIG_DIR/quickshell/hyprquickpaper/config.json"
if [[ -f "$HYPRQUICKPAPER_CONFIG" ]]; then
    sed -i "s|/home/[^/]*/|/home/$USER/|g" "$HYPRQUICKPAPER_CONFIG"
    echo "  - Updated user paths in hyprquickpaper config.json"
fi

# Set default monitor configuration and add English instruction comment in hyprland.lua
HYPR_LUA_CONFIG="$CONFIG_DIR/hypr/hyprland.lua"
if [[ -f "$HYPR_LUA_CONFIG" ]]; then
    cat << 'EOF' > "$HYPR_LUA_CONFIG"
-- Change this to your monitor configurations
hl.monitor({ output = "", mode = "preferred", position = "0x0", scale = 1 })
EOF
    echo "  - Configured default monitor with English instructions in hyprland.lua"
fi

# --------------------------------------------
# Done
# --------------------------------------------

echo
echo "Installation complete!"
echo
echo "Log out and back into Hyprland to apply the configuration."
echo
echo "To verify everything is working, run:"
echo "  hyprctl version"
echo "  waybar --version"
echo
echo "Enjoy your setup!"