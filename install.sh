#!/usr/bin/env bash

set -euo pipefail

# ============================================
# Hyprland-configs Installer (Fully Automated)
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

# Keep-alive sudo privileges in the background
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

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
    makepkg -si --noconfirm --needed
    cd "$REPO_DIR"
    rm -rf /tmp/yay
fi

# --------------------------------------------
# Uninstall unwanted packages (htop, vim, dolphin)
# --------------------------------------------

echo
echo "Checking for packages to remove (htop, vim, dolphin)..."

packages_to_remove=()
for pkg in htop vim dolphin; do
    if pacman -Qi "$pkg" &>/dev/null; then
        packages_to_remove+=("$pkg")
    fi
done

if [[ ${#packages_to_remove[@]} -gt 0 ]]; then
    echo "Removing unwanted packages: ${packages_to_remove[*]}..."
    sudo pacman -Rns --noconfirm "${packages_to_remove[@]}"
    echo "  - Packages successfully uninstalled."
else
    echo "  - None of the specified packages (htop, vim, dolphin) are installed."
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
        sudo pacman -S --needed --noconfirm "${official_packages[@]}"
    fi
    
    mapfile -t aur_packages < <(printf '%s\n' "$aur_packages_raw" | grep -Ev '^[[:space:]]*$' || true)
    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        if command -v yay &>/dev/null; then
            echo "Installing AUR packages via yay..."
            yay -S --needed --noconfirm "${aur_packages[@]}"
        elif command -v paru &>/dev/null; then
            echo "Installing AUR packages via paru..."
            paru -S --needed --noconfirm "${aur_packages[@]}"
        else
            echo "Neither yay nor paru is installed, skipping AUR packages."
        fi
    fi
else
    echo "packages.txt not found in repository root."
fi

echo "Dependencies installation step finished."

# --------------------------------------------
# Update XDG User Directories & Defaults
# --------------------------------------------

echo
echo "Updating XDG user directories..."
if command -v xdg-user-dirs-update &>/dev/null; then
    xdg-user-dirs-update
    echo "  - XDG user directories updated successfully."
else
    echo "  - xdg-user-dirs-update command not found. Installing xdg-user-dirs..."
    sudo pacman -S --needed --noconfirm xdg-user-dirs
    xdg-user-dirs-update
    echo "  - XDG user directories updated successfully."
fi

echo "Setting Thunar as default file manager..."
if command -v xdg-mime &>/dev/null; then
    xdg-mime default thunar.desktop inode/directory
    echo "  - Thunar set as default file manager via xdg-mime."
fi

# --------------------------------------------
# Backup existing configurations & Wallpapers (Automatic)
# --------------------------------------------

echo
echo "Checking for existing configurations and wallpapers..."

configs=(
    btop
    nvim
    cava
    fastfetch
    fish
    hypr
    kitty
    quickshell
    swaync
    waybar
    wlogout
    gtk-3.0
    gtk-4.0
    wofi
    xdg-desktop-portal
    Thunar
    xsettingsd
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

if [[ -e "$HOME/.gtkrc-2.0" ]]; then
    existing_configs+=(".gtkrc-2.0")
fi

if [[ -d "$PICTURES_DIR/Wallpapers" ]]; then
    existing_configs+=("Pictures/Wallpapers")
fi

if [[ ${#existing_configs[@]} -gt 0 ]]; then
    BACKUP_DIR="$CONFIG_DIR/backups"
    mkdir -p "$BACKUP_DIR"

    echo "Creating automatic backup of existing configurations..."

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
        elif [[ "$config" == ".gtkrc-2.0" ]]; then
            if [[ -f "$HOME/.gtkrc-2.0" ]]; then
                cp "$HOME/.gtkrc-2.0" "$BACKUP_DIR/"
                echo "  - Backed up .gtkrc-2.0"
            fi
        else
            if [[ -e "$CONFIG_DIR/$config" ]]; then
                cp -r "$CONFIG_DIR/$config" "$BACKUP_DIR/"
                echo "  - Backed up $config"
            fi
        fi
    done

    echo "Backup complete! Location: $BACKUP_DIR"
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

if [[ -f "$REPO_DIR/configs/.gtkrc-2.0" ]]; then
    cp -f "$REPO_DIR/configs/.gtkrc-2.0" "$HOME/"
    echo "  - Installed file: .gtkrc-2.0"
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
    sed -i "s|/home/[^/]*|$HOME|g" "$HYPRQUICKPAPER_CONFIG"
    echo "  - Updated user paths in hyprquickpaper config.json"
fi

# Update user paths dynamically in wlogout style.css
WLOGOUT_STYLE="$CONFIG_DIR/wlogout/style.css"
if [[ -f "$WLOGOUT_STYLE" ]]; then
    sed -i "s|/home/[^/]*|$HOME|g" "$WLOGOUT_STYLE"
    echo "  - Updated user paths in wlogout style.css"
fi

# Set default monitor configuration right below '-- MONITORS' in hyprland.lua
HYPR_LUA_CONFIG="$CONFIG_DIR/hypr/hyprland.lua"
if [[ -f "$HYPR_LUA_CONFIG" ]]; then
    sed -i '/hl\.monitor/d' "$HYPR_LUA_CONFIG"
    sed -i '/-- MONITORS/a \
-- Change this to your monitor configurations\
hl.monitor({ output = "", mode = "preferred", position = "0x0", scale = 1 })' "$HYPR_LUA_CONFIG"
    echo "  - Replaced monitor configs right below '-- MONITORS' in hyprland.lua"
fi

# --------------------------------------------
# Done & Reboot Option
# --------------------------------------------

echo
echo "Installation complete!"
echo "You need to restart your system to apply all changes properly."
echo

read -rp "Would you like to reboot now? [Y/n]: " reboot_choice
reboot_choice="${reboot_choice:-Y}"

if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    echo "Rebooting system..."
    sudo reboot
else
    echo "Reboot skipped. Please remember to restart your system later to finalize setup."
fi