#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
PICTURES_DIR="$HOME/Pictures"

echo "Welcome to Hyprland-configs Installer!"
echo

# --------------------------------------------
# WARNING BANNER
# --------------------------------------------
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}"
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                          ⚠  WARNING  ⚠                             ║"
echo "╠════════════════════════════════════════════════════════════════════╣"
echo -e "║ ${YELLOW}This script is designed for a FRESH Arch Linux installation.${RED}       ║"
echo "║                                                                    ║"
echo -e "║ ${YELLOW}•${NC} It backs up your current configs to ${YELLOW}~/.config/backups/${RED}           ║"
echo "║   but IMMEDIATELY overwrites them with the dotfiles version.       ║"
echo "║                                                                    ║"
echo -e "║ ${YELLOW}•${NC} It fixes DRM (Widevine/VAAPI) for the ${YELLOW}Helium browser    ${RED}         ║"
echo "║   and installs a policy to prevent accidental Google account       ║"
echo "║   disconnections — since Helium is a privacy-focused browser.      ║"
echo "║                                                                    ║"
echo -e "║ ${YELLOW}•${NC} It also removes ${YELLOW}htop, vim, and dolphin${RED}      if installed,        ║"
echo -e "║   and changes your default shell to ${YELLOW}fish${RED}.                          ║"
echo "║                                                                    ║"
echo "║ This will overwrite your current settings (a backup of your        ║"
echo "║ settings will be created, but active ones are immediately          ║"
echo "║ replaced by the dotfiles version).                                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"


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
# Ensure jq is available (used for monitor detection)
# --------------------------------------------
if ! command -v jq &>/dev/null; then
    echo
    echo "Installing jq (required for monitor auto-detection)..."
    sudo pacman -S --needed --noconfirm jq
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
    gtk-4.0 wofi xdg-desktop-portal
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

if [[ -f "$CONFIG_DIR/fastfetch/storage.sh" ]]; then
    chmod +x "$CONFIG_DIR/fastfetch/storage.sh"
    echo "  - Granted execution permission to fastfetch storage.sh"
fi

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

# --------------------------------------------
# Configure monitors.lua (auto-detect via hyprctl / sysfs)
# --------------------------------------------
echo
echo "Detecting connected monitors..."

MONITORS_LUA_CONFIG="$CONFIG_DIR/hypr/monitors.lua"

# --- Gather monitor info ---
# Priority: hyprctl (running Hyprland) -> sysfs (fresh install, no WM yet)
monitor_entries=()

if command -v hyprctl &>/dev/null && hyprctl monitors -j &>/dev/null; then
    echo "  Hyprland is running. Reading active monitors via hyprctl."
    monitors_json=$(hyprctl monitors -j)
    count=$(echo "$monitors_json" | jq 'length')

    for i in $(seq 0 $((count - 1))); do
        name=$(echo "$monitors_json" | jq -r ".[$i].name")
        width=$(echo "$monitors_json" | jq -r ".[$i].width")
        height=$(echo "$monitors_json" | jq -r ".[$i].height")
        refresh=$(echo "$monitors_json" | jq -r ".[$i].refreshRate")
        refresh_int=$(printf "%.0f" "$refresh")
        monitor_entries+=("${name}|${width}x${height}@${refresh_int}")
    done
else
    echo "  Hyprland not running. Falling back to sysfs detection."
    for card_dir in /sys/class/drm/card*-*/; do
        [[ -f "$card_dir/status" ]] || continue
        grep -q "^connected" "$card_dir/status" 2>/dev/null || continue

        name=$(basename "$card_dir" | sed -E 's/^card[0-9]+-//')
        [[ -z "$name" ]] && continue

        if [[ -s "$card_dir/modes" ]]; then
            res=$(head -n 1 "$card_dir/modes" | grep -oE '^[0-9]+x[0-9]+')
            [[ -n "$res" ]] && monitor_entries+=("${name}|${res}")
        fi
    done
fi

# --- Sort monitors by area (largest resolution = primary at 0x0) ---
if [[ ${#monitor_entries[@]} -gt 1 ]]; then
    sorted_entries=()
    for entry in "${monitor_entries[@]}"; do
        name="${entry%%|*}"
        mode="${entry##*|}"
        width=$(echo "$mode" | grep -oE '^[0-9]+')
        height=$(echo "$mode" | grep -oE 'x[0-9]+' | tr -d 'x')
        area=$((width * height))
        sorted_entries+=("${area}|${name}|${mode}")
    done

    # Sort descending by area
    IFS=$'\n' sorted_entries=($(sort -t'|' -k1,1 -rn <<< "${sorted_entries[*]}")); unset IFS

    # Rebuild monitor_entries in sorted order (largest first)
    monitor_entries=()
    for entry in "${sorted_entries[@]}"; do
        name=$(echo "$entry" | cut -d'|' -f2)
        mode=$(echo "$entry" | cut -d'|' -f3)
        monitor_entries+=("${name}|${mode}")
    done
fi

# --- Write the file ---
mkdir -p "$(dirname "$MONITORS_LUA_CONFIG")"

{
    echo "-- MONITORS & WORKSPACES"
    echo "-- ============================================================"
    echo "-- Auto-generated by install.sh"
    echo "--"
    echo "-- Monitors are sorted by resolution (largest = primary at 0x0)."
    echo "--"
    echo "-- Position reference:"
    echo "--   \"0x0\"    -> primary monitor (origin point, centered)"
    echo "--   \"Wx0\"    -> monitor placed to the RIGHT of the previous one"
    echo "--   \"-Wx0\"   -> monitor placed to the LEFT of the previous one"
    echo "--"
    echo "-- If your secondary monitor is physically on the LEFT side,"
    echo "-- edit its position to a negative value."
    echo "-- Example: \"-1920x0\" places the monitor to the LEFT."
    echo "-- ============================================================"
    echo "local M = {}"
    echo ""
    echo "function M.setup()"

    if [[ ${#monitor_entries[@]} -eq 0 ]]; then
        echo "    -- No monitors detected during install."
        echo "    -- Run 'hyprctl monitors' after login and edit this file."
        echo "    hl.monitor({ output = \"\", mode = \"preferred\", position = \"auto\", scale = 1 })"
    else
        pos_x=0
        first_monitor=""

        for i in "${!monitor_entries[@]}"; do
            entry="${monitor_entries[$i]}"
            name="${entry%%|*}"
            mode="${entry##*|}"
            width=$(echo "$mode" | grep -oE '^[0-9]+')

            if [[ $i -eq 0 ]]; then
                pos="0x0"
                first_monitor="$name"
            else
                pos="${pos_x}x0"
            fi

            printf '    hl.monitor({ output = "%s", mode = "%s", position = "%s", scale = 1 })\n' \
                "$name" "$mode" "$pos"

            pos_x=$((pos_x + width))
        done

        echo ""
        echo "    -- ============================================================"
        echo "    -- WORKSPACES"
        echo "    -- ============================================================"
        printf '    hl.workspace_rule({ workspace = 1, monitor = "%s", persistent = true })\n' "$first_monitor"
        printf '    hl.workspace_rule({ workspace = 2, monitor = "%s", persistent = true })\n' "$first_monitor"
        printf '    hl.workspace_rule({ workspace = 3, monitor = "%s", persistent = true })\n' "$first_monitor"
        printf '    hl.workspace_rule({ workspace = 4, monitor = "%s", persistent = true })\n' "$first_monitor"

        if [[ ${#monitor_entries[@]} -ge 2 ]]; then
            second_entry="${monitor_entries[1]}"
            second_monitor="${second_entry%%|*}"
            printf '    hl.workspace_rule({ workspace = 6, monitor = "%s", persistent = true, default = true })\n' "$second_monitor"
        fi
    fi

    echo "end"
    echo ""
    echo "return M"
} > "$MONITORS_LUA_CONFIG"

if [[ ${#monitor_entries[@]} -gt 0 ]]; then
    echo "  Generated $MONITORS_LUA_CONFIG with ${#monitor_entries[@]} monitor(s)"
else
    echo "  Generated $MONITORS_LUA_CONFIG with generic fallback"
fi

# --------------------------------------------
# Configure Waybar output (auto-detect to prevent hidden bar)
# --------------------------------------------
echo
echo "Configuring Waybar output..."

WAYBAR_CONFIG="$CONFIG_DIR/waybar/config.json"

if [[ -f "$WAYBAR_CONFIG" ]]; then
    if [[ -n "${first_monitor:-}" ]]; then
        # Set Waybar output to the auto-detected primary monitor
        if grep -q '"output"' "$WAYBAR_CONFIG"; then
            sed -i "s|\"output\":[[:space:]]*\"[^\"]*\"|\"output\": \"${first_monitor}\"|" "$WAYBAR_CONFIG"
            echo "  - Set Waybar output to detected monitor: $first_monitor"
        else
            echo "  - Waybar config has no 'output' field, using default (all monitors)"
        fi
    else
        # No monitor detected - remove the hardcoded output so bar shows everywhere
        if grep -q '"output"' "$WAYBAR_CONFIG"; then
            sed -i '/"output":/d' "$WAYBAR_CONFIG"
            echo "  - No monitor detected. Removed 'output' line from Waybar config"
            echo "  - Waybar will show on all monitors"
        else
            echo "  - Waybar config has no 'output' field, nothing to change"
        fi
    fi
else
    echo "  - Waybar config not found, skipping"
fi

# --------------------------------------------
# Configure EasyEffects systemd user service
# --------------------------------------------
echo
echo "Configuring EasyEffects user service..."

SYSTEMD_USER_DIR="$CONFIG_DIR/systemd/user"
EASYEFFECTS_SERVICE="$SYSTEMD_USER_DIR/easyeffects.service"

mkdir -p "$SYSTEMD_USER_DIR"

cat > "$EASYEFFECTS_SERVICE" << EOF
[Unit]
Description=EasyEffects Service
Wants=pipewire-pulse.service
After=pipewire-pulse.service
BindsTo=pipewire-pulse.service
PartOf=pipewire-pulse.service

[Service]
Environment=DISPLAY=:0
Environment=XAUTHORITY=${HOME}/.Xauthority
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
ExecStart=/usr/bin/easyeffects --gapplication-service
Restart=always
RestartSec=3
StartLimitInterval=0

[Install]
WantedBy=default.target
EOF

echo "  - Created EasyEffects service file"

if command -v systemctl &>/dev/null; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable easyeffects.service 2>/dev/null || true
    echo "  - Enabled EasyEffects service (will start on next login)"
fi

# --------------------------------------------
# Configure Desktop Entries for Terminal Apps (btop & nvim)
# --------------------------------------------
echo
echo "Configuring local desktop entries for btop and nvim..."

DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"

create_desktop_entry() {
    local src_file="$1"
    local dest_name="$2"
    local exec_cmd="$3"
    local local_file="$DESKTOP_DIR/$dest_name"
    
    if [[ ! -f "$src_file" ]]; then
        echo "  Warning: Source file not found: $src_file"
        return 1
    fi
    
    cp "$src_file" "$local_file"
    
    if [[ ! -f "$local_file" ]]; then
        echo "  Error: Failed to copy $src_file"
        return 1
    fi
    
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
    echo "  Configured: $dest_name"
    return 0
}

create_desktop_entry "/usr/share/applications/btop.desktop" "btop.desktop" "kitty -e btop"

if [[ -f "/usr/share/applications/nvim.desktop" ]]; then
    create_desktop_entry "/usr/share/applications/nvim.desktop" "nvim.desktop" "kitty -e nvim %F"
elif [[ -f "/usr/share/applications/neovim.desktop" ]]; then
    create_desktop_entry "/usr/share/applications/neovim.desktop" "nvim.desktop" "kitty -e nvim %F"
else
    echo "  Warning: nvim.desktop not found, skipping..."
fi

if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    echo "  Desktop database updated."
fi

echo
echo "Desktop entries created:"
found=0
for entry in btop.desktop nvim.desktop; do
    if [[ -f "$DESKTOP_DIR/$entry" ]]; then
        ls -la "$DESKTOP_DIR/$entry"
        found=1
    fi
done
if [[ "$found" -eq 0 ]]; then
    echo "  Warning: No desktop entries found"
fi

# --------------------------------------------
# Install Flatpak Apps (Bazaar)
# --------------------------------------------
echo
echo "Configuring Flathub and installing Bazaar..."
if command -v flatpak &>/dev/null; then
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub io.github.kolunmi.Bazaar
    echo "  - Bazaar successfully installed."
else
    echo "  - Flatpak is not installed, skipping Bazaar installation."
fi

# --------------------------------------------
# Helium DRM Fixer Automation
# --------------------------------------------
echo
echo "Starting Helium DRM Fixer setup..."

# Install bun
sudo pacman -S --needed --noconfirm bun

# Prepare temporary directory
rm -rf /tmp/helium-drm-fixer
git clone https://github.com/PHNexus/helium-drm-fixer.git /tmp/helium-drm-fixer

echo "Installing Google Chrome temporarily via $AUR_HELPER..."
"$AUR_HELPER" -S --needed --noconfirm google-chrome

# Run the DRM fix
cd /tmp/helium-drm-fixer
bun install
# Note: The script might pause here if cli.ts requires (Y/n) confirmation
bun run cli.ts

echo "Uninstalling Google Chrome..."
# Safely remove Chrome and its unused dependencies
sudo pacman -Rns --noconfirm google-chrome

echo "Cleaning up remaining Chrome traces..."
# Remove user config and cache files
rm -rf "$HOME/.config/google-chrome"
rm -rf "$HOME/.cache/google-chrome"

# Dynamically clear the cache for the detected AUR helper
if [[ "$AUR_HELPER" == "yay" ]]; then
    rm -rf "$HOME/.cache/yay/google-chrome"
elif [[ "$AUR_HELPER" == "paru" ]]; then
    rm -rf "$HOME/.cache/paru/clone/google-chrome"
fi

# Clean up temporary fixer repository
rm -rf /tmp/helium-drm-fixer

cd "$REPO_DIR"
echo "Helium DRM Fixer completed successfully!"

# --------------------------------------------
# Configure Helium Browser Flags
# --------------------------------------------
echo
echo "Configuring Helium browser flags..."
mkdir -p "$CONFIG_DIR"
cat << 'EOF' > "$CONFIG_DIR/helium-browser-flags.conf"
--enable-features=VaapiVideoDecoder,AcceleratedVideoDecodeLinuxGL
--ignore-gpu-blocklist
--enable-zero-copy
--ozone-platform=wayland
EOF
echo "  - Created helium-browser-flags.conf successfully."

# --------------------------------------------
# Configure Helium Cookie Exceptions via Policy
# --------------------------------------------
echo
echo "Configuring Helium cookie exceptions..."
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
echo "  - Cookie exceptions policy configured successfully."

# --------------------------------------------
# Install and Configure GameMode
# --------------------------------------------
echo
echo "Installing and configuring GameMode..."

# 1. Install GameMode and 32-bit support
sudo pacman -S --needed --noconfirm gamemode lib32-gamemode

# 2. Enable and start systemd user service
if command -v systemctl &>/dev/null; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now gamemoded.service 2>/dev/null || true
    echo "  - Enabled gamemoded user service."
fi

# 3. Download default configuration file from official repository
if [[ ! -f "$CONFIG_DIR/gamemode.ini" ]]; then
    curl -sLo "$CONFIG_DIR/gamemode.ini" https://raw.githubusercontent.com/FeralInteractive/gamemode/master/example/gamemode.ini
    echo "  - Downloaded default gamemode.ini to $CONFIG_DIR/"
fi

echo "GameMode setup completed successfully!"

# --------------------------------------------
# Configure cpupower for Performance mode
# --------------------------------------------
echo
echo "Configuring cpupower for Performance mode..."
if [[ -f /etc/default/cpupower-service.conf ]]; then
    sudo sed -i '/GOVERNOR/d' /etc/default/cpupower-service.conf
    echo 'GOVERNOR="performance"' | sudo tee -a /etc/default/cpupower-service.conf > /dev/null
    sudo systemctl enable --now cpupower.service
    echo "  - cpupower service enabled with 'performance' governor."
else
    echo "  - cpupower-service.conf not found, skipping."
fi

# --------------------------------------------
# Remove NVIDIA environment variables if NVIDIA is NOT detected
# --------------------------------------------
echo
echo "Checking GPU vendor to adjust Hyprland environment variables..."

ENV_LUA_FILE="$HOME/.config/hypr/environment.lua"

if ! lspci -nn | grep -iE 'vga|3d' | grep -iEq 'nvidia'; then
    echo "  - NVIDIA GPU not detected. Removing NVIDIA environment variables..."
    if [[ -f "$ENV_LUA_FILE" ]]; then

        sed -i -E '/(LIBVA_DRIVER_NAME|__GLX_VENDOR_LIBRARY_NAME|GBM_BACKEND|NVD_BACKEND|VDPAU_DRIVER|__GL_SHADER_DISK_CACHE|__GL_SYNC_TO_VBLANK)/I d' "$ENV_LUA_FILE"
        
        sed -i '/-- NVIDIA/d' "$ENV_LUA_FILE"
        
        echo "  - NVIDIA environment variables successfully removed from environment.lua."
    else
        echo "  - Warning: $ENV_LUA_FILE not found, skipping GPU env adjustment."
    fi
else
    echo "  - NVIDIA GPU detected, keeping original environment variables."
fi

# --------------------------------------------
# Set Fish as Default Shell
# --------------------------------------------
echo
echo "Setting fish as the default shell..."
if command -v fish &>/dev/null; then
    if ! grep -q "$(which fish)" /etc/shells; then
        which fish | sudo tee -a /etc/shells
    fi
    sudo chsh -s "$(which fish)" "$USER"
    echo "  - Default shell changed to fish."
else
    echo "  - Fish is not installed, skipping."
fi

echo
echo "Installation complete!"
read -rp "Would you like to reboot now? [Y/n]: " reboot_choice
reboot_choice="${reboot_choice:-Y}"

if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    sudo reboot
fi