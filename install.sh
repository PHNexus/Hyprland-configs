#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
PICTURES_DIR="$HOME/Pictures"

echo "Welcome to Hyprland-configs Installer!"
echo

# --------------------------------------------
# Check OS & Root Execution
# --------------------------------------------
if [[ ! -f /etc/arch-release ]]; then
    echo "Error: This installer is designed for Arch Linux."
    exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
    echo "Error: Do not run this script as root/sudo directly. Run it as a normal user."
    exit 1
fi

echo "Arch Linux detected."

# --------------------------------------------
# Check sudo access
# --------------------------------------------
if ! sudo -v; then
    echo "Error: sudo access is required."
    exit 1
fi

# --------------------------------------------
# Ensure base-devel and select AUR helper
# --------------------------------------------
echo
echo "Ensuring base-devel and git are installed..."
sudo pacman -S --needed --noconfirm base-devel git

AUR_HELPER=""
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
else
    echo "AUR helper not found. Installing yay automatically..."
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm --needed
    cd "$REPO_DIR"
    rm -rf /tmp/yay
    AUR_HELPER="yay"
fi

echo "Using AUR helper: $AUR_HELPER"

# --------------------------------------------
# Uninstall unwanted packages
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
    official_packages=()
    aur_packages=()
    is_aur=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^#AUR ]]; then
            is_aur=1
            continue
        fi

        [[ "$line" =~ ^# ]] && continue

        if [[ $is_aur -eq 0 ]]; then
            official_packages+=("$line")
        else
            aur_packages+=("$line")
        fi
    done < "$REPO_DIR/packages.txt"

    if [[ ${#official_packages[@]} -gt 0 ]]; then
        echo "Installing official packages via pacman..."
        sudo pacman -S --needed --noconfirm "${official_packages[@]}"
    fi

    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        echo "Installing AUR packages via $AUR_HELPER..."
        "$AUR_HELPER" -S --needed --noconfirm "${aur_packages[@]}"
    fi
else
    echo "packages.txt not found in repository root."
fi

# --------------------------------------------
# Update XDG User Directories & Defaults
# --------------------------------------------
echo
echo "Updating XDG user directories..."
if ! command -v xdg-user-dirs-update &>/dev/null; then
    sudo pacman -S --needed --noconfirm xdg-user-dirs
fi
xdg-user-dirs-update

if command -v xdg-mime &>/dev/null; then
    xdg-mime default thunar.desktop inode/directory
fi

# --------------------------------------------
# Backup existing configurations
# --------------------------------------------
echo
echo "Checking for existing configurations and wallpapers..."

configs=(
    btop nvim cava fastfetch fish hypr kitty
    quickshell swaync waybar wlogout gtk-3.0
    gtk-4.0 wofi xdg-desktop-portal Thunar xsettingsd
)

existing_configs=()

for config in "${configs[@]}"; do
    if [[ -e "$CONFIG_DIR/$config" ]]; then
        existing_configs+=("$config")
    fi
done

[[ -f "$CONFIG_DIR/starship.toml" ]] && existing_configs+=("starship.toml")
[[ -f "$HOME/.gtkrc-2.0" ]] && existing_configs+=(".gtkrc-2.0")
[[ -d "$PICTURES_DIR/Wallpapers" ]] && existing_configs+=("Pictures/Wallpapers")

if [[ ${#existing_configs[@]} -gt 0 ]]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="$CONFIG_DIR/backups/backup_$TIMESTAMP"
    mkdir -p "$BACKUP_DIR"

    echo "Creating automatic backup at: $BACKUP_DIR"

    for item in "${existing_configs[@]}"; do
        if [[ "$item" == "Pictures/Wallpapers" ]]; then
            mkdir -p "$BACKUP_DIR/Pictures"
            cp -r "$PICTURES_DIR/Wallpapers" "$BACKUP_DIR/Pictures/"
        elif [[ "$item" == "starship.toml" ]]; then
            cp "$CONFIG_DIR/starship.toml" "$BACKUP_DIR/"
        elif [[ "$item" == ".gtkrc-2.0" ]]; then
            cp "$HOME/.gtkrc-2.0" "$BACKUP_DIR/"
        else
            cp -r "$CONFIG_DIR/$item" "$BACKUP_DIR/"
        fi
        echo "  - Backed up $item"
    done
fi

# --------------------------------------------
# Install configurations & Wallpapers
# --------------------------------------------
echo
echo "Installing dotfiles configurations..."

mkdir -p "$CONFIG_DIR"

for config in "${configs[@]}"; do
    if [[ -d "$REPO_DIR/configs/$config" ]]; then
        rm -rf "${CONFIG_DIR:?}/$config"
        cp -r "$REPO_DIR/configs/$config" "$CONFIG_DIR/"
        echo "  - Installed config: $config"
    fi
done

if [[ -f "$REPO_DIR/configs/starship.toml" ]]; then
    cp -f "$REPO_DIR/configs/starship.toml" "$CONFIG_DIR/"
fi

if [[ -f "$REPO_DIR/configs/.gtkrc-2.0" ]]; then
    cp -f "$REPO_DIR/configs/.gtkrc-2.0" "$HOME/"
fi

if [[ -d "$REPO_DIR/Wallpapers" ]]; then
    mkdir -p "$PICTURES_DIR/Wallpapers"
    cp -ru "$REPO_DIR/Wallpapers/." "$PICTURES_DIR/Wallpapers/"
fi

# --------------------------------------------
# Post-install Adjustments
# --------------------------------------------
echo
echo "Applying post-installation adjustments..."

ESCAPED_HOME=$(printf '%s\n' "$HOME" | sed 's/[&/\]/\\&/g')

HYPRQUICKPAPER_CONFIG="$CONFIG_DIR/quickshell/hyprquickpaper/config.json"
if [[ -f "$HYPRQUICKPAPER_CONFIG" ]]; then
    sed -i "s|/home/[^/]*|${ESCAPED_HOME}|g" "$HYPRQUICKPAPER_CONFIG"
fi

WLOGOUT_STYLE="$CONFIG_DIR/wlogout/style.css"
if [[ -f "$WLOGOUT_STYLE" ]]; then
    sed -i "s|/home/[^/]*|${ESCAPED_HOME}|g" "$WLOGOUT_STYLE"
fi

HYPR_LUA_CONFIG="$CONFIG_DIR/hypr/hyprland.lua"
if [[ -f "$HYPR_LUA_CONFIG" ]]; then
    sed -i '/hl\.monitor/d' "$HYPR_LUA_CONFIG"
    sed -i '/-- Change this to your actual monitor configuration if needed/d' "$HYPR_LUA_CONFIG"
    sed -i '/-- Change this to your monitor configurations/d' "$HYPR_LUA_CONFIG"
    sed -i '/-- MONITORS/{n;/^$/d}' "$HYPR_LUA_CONFIG"
    sed -i '/-- MONITORS/a -- Change this to your monitor configurations\nhl.monitor({ output = "", mode = "preferred", position = "0x0", scale = 1 })' "$HYPR_LUA_CONFIG"
fi

# --------------------------------------------
# Configure Desktop Entries for Terminal Apps (btop & nvim)
# --------------------------------------------
echo
echo "Configuring local desktop entries for btop and nvim..."

DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"

# Function to create/modify .desktop files
create_desktop_entry() {
    local src_file="$1"
    local dest_name="$2"
    local exec_cmd="$3"
    local local_file="$DESKTOP_DIR/$dest_name"
    
    # Check if source file exists
    if [[ ! -f "$src_file" ]]; then
        echo "  Warning: Source file not found: $src_file"
        return 1
    fi
    
    # Copy the file
    cp "$src_file" "$local_file"
    
    # Verify copy was successful
    if [[ ! -f "$local_file" ]]; then
        echo "  Error: Failed to copy $src_file"
        return 1
    fi
    
    # Replace or add the Exec= line
    if grep -q "^Exec=" "$local_file"; then
        # If exists, replace it
        sed -i "s|^Exec=.*|Exec=$exec_cmd|" "$local_file"
    else
        # If not exists, add it
        echo "Exec=$exec_cmd" >> "$local_file"
    fi
    
    # Ensure correct permissions
    chmod 644 "$local_file"
    
    echo "  Configured: $dest_name"
    return 0
}

# Configure btop
create_desktop_entry "/usr/share/applications/btop.desktop" "btop.desktop" "kitty -e btop"

# Configure nvim (try both possible names)
if [[ -f "/usr/share/applications/nvim.desktop" ]]; then
    create_desktop_entry "/usr/share/applications/nvim.desktop" "nvim.desktop" "kitty -e nvim %F"
elif [[ -f "/usr/share/applications/neovim.desktop" ]]; then
    create_desktop_entry "/usr/share/applications/neovim.desktop" "nvim.desktop" "kitty -e nvim %F"
else
    echo "  Warning: nvim.desktop not found, skipping..."
fi

# Update desktop database cache
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    echo "  Desktop database updated."
fi

# verification
echo
echo "Desktop entries created:"
ls -la "$DESKTOP_DIR" | grep -E "(btop|nvim)" || echo "  Warning: No desktop entries found"

# --------------------------------------------
# Install Flatpak Apps (Bazaar)
# --------------------------------------------
echo
echo "Configuring Flathub and installing Bazaar..."
if command -v flatpak &>/dev/null; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub io.github.kolunmi.Bazaar
    echo "  - Bazaar successfully installed."
else
    echo "  - Flatpak is not installed, skipping Bazaar installation."
fi

echo
echo "Installation complete!"
read -rp "Would you like to reboot now? [Y/n]: " reboot_choice
reboot_choice="${reboot_choice:-Y}"

if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    sudo reboot
fi