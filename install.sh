#!/usr/env bash

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
else
    echo "  - None of the specified packages are installed."
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
        sudo pacman -S --needed --noconfirm "${official_packages[@]}"
    fi

    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        "$AUR_HELPER" -S --needed --noconfirm "${aur_packages[@]}"
    fi
else
    echo "packages.txt not found."
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
echo "Checking for existing configurations..."

configs=(
    btop nvim cava fastfetch fish hypr kitty
    quickshell swaync waybar wlogout gtk-3.0
    gtk-4.0 wofi xdg-desktop-portal
)

existing_configs=()
for config in "${configs[@]}"; do
    [[ -e "$CONFIG_DIR/$config" ]] && existing_configs+=("$config")
done

[[ -f "$CONFIG_DIR/starship.toml" ]] && existing_configs+=("starship.toml")
[[ -f "$HOME/.gtkrc-2.0" ]] && existing_configs+=(".gtkrc-2.0")
[[ -d "$PICTURES_DIR/Wallpapers" ]] && existing_configs+=("Pictures/Wallpapers")

if [[ ${#existing_configs[@]} -gt 0 ]]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="$CONFIG_DIR/backups/backup_$TIMESTAMP"
    mkdir -p "$BACKUP_DIR"
    echo "Creating backup at: $BACKUP_DIR"

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
    done
fi

# --------------------------------------------
# Install configurations & Wallpapers
# --------------------------------------------
echo
echo "Installing dotfiles..."
mkdir -p "$CONFIG_DIR"

for config in "${configs[@]}"; do
    if [[ -d "$REPO_DIR/configs/$config" ]]; then
        rm -rf "${CONFIG_DIR:?}/$config"
        cp -r "$REPO_DIR/configs/$config" "$CONFIG_DIR/"
    fi
done

if [[ -f "$CONFIG_DIR/fastfetch/storage.sh" ]]; then
    chmod +x "$CONFIG_DIR/fastfetch/storage.sh"
fi

[[ -f "$REPO_DIR/configs/starship.toml" ]] && cp -f "$REPO_DIR/configs/starship.toml" "$CONFIG_DIR/"
[[ -f "$REPO_DIR/configs/.gtkrc-2.0" ]] && cp -f "$REPO_DIR/configs/.gtkrc-2.0" "$HOME/"

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
[[ -f "$HYPRQUICKPAPER_CONFIG" ]] && sed -i "s|/home/[^/]*|${ESCAPED_HOME}|g" "$HYPRQUICKPAPER_CONFIG"

WLOGOUT_STYLE="$CONFIG_DIR/wlogout/style.css"
[[ -f "$WLOGOUT_STYLE" ]] && sed -i "s|/home/[^/]*|${ESCAPED_HOME}|g" "$WLOGOUT_STYLE"

# Adjusted to target monitors.lua instead of hyprland.lua
MONITORS_LUA_CONFIG="$CONFIG_DIR/hypr/monitors.lua"
if [[ -f "$MONITORS_LUA_CONFIG" ]]; then
    sed -i 's/hl\.monitor({ output = "[^"]*"/hl.monitor({ output = ""/' "$MONITORS_LUA_CONFIG"
else
    cat << 'EOF' > "$MONITORS_LUA_CONFIG"
-- MONITORS & WORKSPACES
local M = {}

function M.setup()
    hl.monitor({ output = "", mode = "preferred", position = "0x0", scale = 1 })
end

return M
EOF
fi

# --------------------------------------------
# Configure Desktop Entries for Terminal Apps
# --------------------------------------------
echo
echo "Configuring desktop entries for btop and nvim..."

DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"

create_desktop_entry() {
    local src_file="$1"
    local dest_name="$2"
    local exec_cmd="$3"
    local local_file="$DESKTOP_DIR/$dest_name"
    
    [[ ! -f "$src_file" ]] && return 1
    cp "$src_file" "$local_file"
    [[ ! -f "$local_file" ]] && return 1
    
    if grep -q "^Exec=" "$local_file"; then
        sed -i "s|^Exec=.*|Exec=$exec_cmd|" "$local_file"
    else
        echo "Exec=$exec_cmd" >> "$local_file"
    fi
    
    if grep -q "^Terminal=" "$local_file"; then
        sed -i "s|^Terminal=.*|Terminal=false|" "$local_file"
    else
        echo "Terminal=false" >> "$local_file"
    fi
    
    chmod 644 "$local_file"
}

create_desktop_entry "/usr/share/applications/btop.desktop" "btop.desktop" "kitty -e btop"

if [[ -f "/usr/share/applications/nvim.desktop" ]]; then
    create_desktop_entry "/usr/share/applications/nvim.desktop" "nvim.desktop" "kitty -e nvim %F"
elif [[ -f "/usr/share/applications/neovim.desktop" ]]; then
    create_desktop_entry "/usr/share/applications/neovim.desktop" "nvim.desktop" "kitty -e nvim %F"
fi

command -v update-desktop-database &>/dev/null && update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

# --------------------------------------------
# Install Flatpak Apps (Bazaar)
# --------------------------------------------
echo
echo "Configuring Flathub and installing Bazaar..."
if command -v flatpak &>/dev/null; then
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub io.github.kolunmi.Bazaar
fi

# --------------------------------------------
# Helium DRM Fixer Automation
# --------------------------------------------
echo
echo "Starting Helium DRM Fixer setup..."

sudo pacman -S --needed --noconfirm bun

rm -rf /tmp/helium-drm-fixer
git clone https://github.com/PHNexus/helium-drm-fixer.git /tmp/helium-drm-fixer

"$AUR_HELPER" -S --needed --noconfirm google-chrome

cd /tmp/helium-drm-fixer
bun install
bun run cli.ts

sudo pacman -Rns --noconfirm google-chrome
rm -rf "$HOME/.config/google-chrome" "$HOME/.cache/google-chrome"

if [[ "$AUR_HELPER" == "yay" ]]; then
    rm -rf "$HOME/.cache/yay/google-chrome"
elif [[ "$AUR_HELPER" == "paru" ]]; then
    rm -rf "$HOME/.cache/paru/clone/google-chrome"
fi

rm -rf /tmp/helium-drm-fixer
cd "$REPO_DIR"

# --------------------------------------------
# Configure Helium Browser Flags & Policies
# --------------------------------------------
echo
echo "Configuring Helium browser flags and policies..."
mkdir -p "$CONFIG_DIR"
cat << 'EOF' > "$CONFIG_DIR/helium-browser-flags.conf"
--enable-features=VaapiVideoDecoder,AcceleratedVideoDecodeLinuxGL
--ignore-gpu-blocklist
--enable-zero-copy
--ozone-platform=wayland
EOF

sudo mkdir -p /etc/chromium/policies/managed
sudo tee /etc/chromium/policies/managed/cookie_exceptions.json > /dev/null << 'EOF'
{
  "CookiesAllowedForUrls": [
    "[*.]google.com",
    "[*.]accounts.google.com",
    "accounts.google.com",
    "google.com"
  ]
}
EOF

# --------------------------------------------
# Set Fish as Default Shell
# --------------------------------------------
echo
echo "Setting fish as the default shell..."
if command -v fish &>/dev/null; then
    if ! grep -q "$(which fish)" /etc/shells; then
        echo "$(which fish)" | sudo tee -a /etc/shells
    fi
    sudo chsh -s "$(which fish)" "$USER"
fi

echo
echo "Installation complete!"
read -rp "Would you like to reboot now? [Y/n]: " reboot_choice
reboot_choice="${reboot_choice:-Y}"

if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    sudo reboot
fi