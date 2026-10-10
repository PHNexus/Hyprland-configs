#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
PICTURES_DIR="$HOME/Pictures"

log() { printf '\n%s\n' "$*"; }
warn() { printf '  Warning: %s\n' "$*" >&2; }

for arg in "$@"; do
    case "$arg" in
        --skip-appmanager) SKIP_APPMANAGER=1 ;;
        -h|--help)
            printf 'Usage: %s [--skip-appmanager]\n' "${0##*/}"
            exit 0
            ;;
        *) printf 'Warning: ignoring unknown argument: %s\n' "$arg" >&2 ;;
    esac
done

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
echo -e "║ ${YELLOW}Designed for a FRESH Arch Linux installation — no prior setup.${RED}     ║"
echo "║                                                                    ║"
echo -e "║ ${YELLOW}•${NC} ${YELLOW}Backups${RED} current configs to ${YELLOW}~/.config/backups/${RED}, then              ║"
echo "║   overwrites them with the dotfiles version.                       ║"
echo "║                                                                    ║"
echo -e "║ ${YELLOW}•${NC} ${YELLOW}Installs${RED} all packages from ${YELLOW}packages.txt${RED} (official + AUR).        ║"
echo "║                                                                    ║"
echo -e "║ ${YELLOW}•${NC} ${YELLOW}Removes${RED} htop, vim, and dolphin if installed, and switches        ║"
echo -e "║   the default shell to ${YELLOW}fish${RED}.                                       ║"
echo "║                                                                    ║"
echo -e "║ ${YELLOW}•${NC} ${YELLOW}Fixes DRM${RED} (Widevine/VAAPI) for the Helium browser and            ║"
echo "║   applies a policy to prevent Google account disconnections.       ║"
echo "║                                                                    ║"
echo -e "║ ${YELLOW}•${NC} ${YELLOW}Detects monitors${RED} automatically and generates Hyprland            ║"
echo "║   config with workspaces bound to the primary display.             ║"
echo "║                                                                    ║"
echo -e "║ ${YELLOW}•${NC} ${YELLOW}Installs dock-bar${RED} (Quickshell) and configures GameMode,          ║"
echo "║   cpupower, Cloudflare WARP + DNS, GTK themes, and EasyEffects.    ║"
echo "║                                                                    ║"
echo -e "║ ${YELLOW}•${NC} ${YELLOW}Adjusts NVIDIA${RED} environment variables based on detected           ║"
echo "║   GPU — removes them on AMD/Intel systems.                         ║"
echo "║                                                                    ║"
echo -e "║ ${YELLOW}Review the script before running. Configs in ~/.config are${RED}         ║"
echo -e "║ ${YELLOW}backed up but immediately replaced. Reboot required after.${RED}         ║"
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
# Ensure multilib repository is enabled
# --------------------------------------------
echo
echo "Ensuring multilib repository is enabled..."
if ! grep -Eq '^[[:space:]]*\[multilib\][[:space:]]*$' /etc/pacman.conf; then
    if grep -Eq '^#[[:space:]]*\[multilib\][[:space:]]*$' /etc/pacman.conf; then
        sudo sed -i '/^#[[:space:]]*\[multilib\][[:space:]]*$/,/^#[[:space:]]*Include[[:space:]]*=[[:space:]]*\/etc\/pacman\.d\/mirrorlist[[:space:]]*$/ s/^#//' /etc/pacman.conf
        if grep -Eq '^[[:space:]]*\[multilib\][[:space:]]*$' /etc/pacman.conf; then
            sudo pacman -Syu --noconfirm
            echo "  - Enabled multilib repository and refreshed package databases."
        else
            echo "Error: Could not safely enable multilib. Check /etc/pacman.conf."
            exit 1
        fi
    else
        echo "Error: Could not find the standard multilib section in /etc/pacman.conf."
        exit 1
    fi
else
    echo "  - Multilib repository already enabled."
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
    YAY_BUILD_DIR="$(mktemp -d /tmp/yay-build.XXXXXX)"
    if git clone https://aur.archlinux.org/yay.git "$YAY_BUILD_DIR/yay"; then
        if ! (cd "$YAY_BUILD_DIR/yay" && makepkg -si --noconfirm --needed); then
            rm -rf -- "$YAY_BUILD_DIR"
            echo "Error: yay could not be built or installed." >&2
            exit 1
        fi
    else
        rm -rf -- "$YAY_BUILD_DIR"
        echo "Error: Could not clone the yay repository." >&2
        exit 1
    fi
    rm -rf -- "$YAY_BUILD_DIR"
    if ! command -v yay &>/dev/null; then
        echo "Error: yay installation failed." >&2
        exit 1
    fi
    AUR_HELPER="yay"
fi

echo "Using AUR helper: $AUR_HELPER"

# Use explicit answers for yay's clean-build/diff/edit menus. --noconfirm alone
# does not suppress these menus on some yay configurations.
aur_install() {
    if [[ "$AUR_HELPER" == "yay" ]]; then
        yay -S --needed --noconfirm --answerclean None --answerdiff None --answeredit None "$@"
    else
        paru -S --needed --noconfirm "$@"
    fi
}

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

        if [[ "$line" =~ ^#[[:space:]]*AUR([[:space:]]|$) ]]; then
            is_aur=1
            continue
        fi

        if [[ "$line" =~ ^#[[:space:]]*Flatpaks([[:space:]]|$) ]]; then
            break
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
        aur_install "${aur_packages[@]}"
    fi
else
    echo "packages.txt not found in repository root."
fi

# --------------------------------------------
# Detect optional packages enabled by packages.txt
# --------------------------------------------
HAS_CLOUDFLARE_WARP=0
HAS_HELIUM_BROWSER=0

if [[ -f "$REPO_DIR/packages.txt" ]]; then
    if grep -qE '^[[:space:]]*cloudflare-warp-bin[[:space:]]*$' "$REPO_DIR/packages.txt"; then
        HAS_CLOUDFLARE_WARP=1
    fi

    if grep -qE '^[[:space:]]*helium-browser-bin[[:space:]]*$' "$REPO_DIR/packages.txt"; then
        HAS_HELIUM_BROWSER=1
    fi
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

# Remove Projects from the global defaults and this user's XDG mappings.
# This does not delete ~/Projects or any other directory.
XDG_DEFAULTS="/etc/xdg/user-dirs.defaults"
if [[ -f "$XDG_DEFAULTS" ]] && grep -qE '^[[:space:]]*PROJECTS[[:space:]]*=' "$XDG_DEFAULTS"; then
    sudo sed -i '/^[[:space:]]*PROJECTS[[:space:]]*=/d' "$XDG_DEFAULTS"
    echo "  - Removed Projects from global XDG defaults."
fi

USER_DIRS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
if [[ -f "$USER_DIRS_CONFIG" ]]; then
    sed -i '/^[[:space:]]*XDG_PROJECTS_DIR[[:space:]]*=/d' "$USER_DIRS_CONFIG"
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
    gtk-4.0 wofi xdg-desktop-portal dock-bar
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

# -----------------------------------------------------------------
# Set Initial Default Wallpaper with Cache
# -----------------------------------------------------------------
DEFAULT_WALLPAPER="$PICTURES_DIR/Wallpapers/02.png"
CACHE_DIR="$HOME/.cache/wallpapers_state"
mkdir -p "$CACHE_DIR"

MONITORS=""
if command -v hyprctl &>/dev/null && command -v jq &>/dev/null; then
    wallpaper_monitors_json="$(hyprctl monitors -j 2>/dev/null || true)"
    if [[ -n "$wallpaper_monitors_json" ]] && jq -e 'type == "array"' >/dev/null 2>&1 <<<"$wallpaper_monitors_json"; then
        MONITORS="$(jq -r '.[].name // empty' <<<"$wallpaper_monitors_json")"
    fi
fi

if command -v awww &>/dev/null && [[ -f "$DEFAULT_WALLPAPER" ]]; then
    if [[ -n "$MONITORS" ]]; then
        awww init || true
        for MONITOR in $MONITORS; do
            awww img -o "$MONITOR" "$DEFAULT_WALLPAPER" -t random --transition-duration 1
            echo "$DEFAULT_WALLPAPER" > "$CACHE_DIR/$MONITOR"
        done
        echo "  - Initial default wallpaper applied and saved to cache for all monitors!"
    else
        echo "  - Hyprland is not running. Skipping initial wallpaper application."
    fi
fi

# --------------------------------------------
# Install Dock Bar (self-contained, no upstream)
# --------------------------------------------
echo
echo "Installing Dock Bar..."

if command -v qs &>/dev/null; then
    DOCK_DIR="$HOME/.local/share/dock-bar"

    if [[ ! -d "$REPO_DIR/dock-bar" ]]; then
        echo "  Warning: $REPO_DIR/dock-bar not found, skipping"
    else
        # Remove any previous install to avoid stale files
        rm -rf "$DOCK_DIR"

        # Copy the dock source from this repo
        mkdir -p "$DOCK_DIR"
        cp -r "$REPO_DIR/dock-bar/." "$DOCK_DIR/"

        # Make the launcher executable
        chmod +x "$DOCK_DIR/bin/dock-bar" 2>/dev/null || true

        # Symlink the launcher
        mkdir -p "$HOME/.local/bin"
        ln -sf "$DOCK_DIR/bin/dock-bar" "$HOME/.local/bin/dock-bar"
        echo "  - Dock Bar installed at ~/.local/share/dock-bar"

        # Warn if ~/.local/bin is not in PATH
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            echo "  Warning: ~/.local/bin is not in \$PATH."
            echo "  Add this to your shell config:"
            echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    fi
else
    echo "  - Quickshell (qs) not found, skipping Dock Bar"
fi

# --------------------------------------------
# Install AppManager (AppImage manager)
# --------------------------------------------
echo
echo "Installing AppManager..."

if [[ "${SKIP_APPMANAGER:-0}" == "1" ]]; then
    echo "  - Skipping AppManager (--skip-appmanager)"
elif ! command -v curl &>/dev/null; then
    echo "  - curl not found, skipping AppManager"
elif ! command -v jq &>/dev/null; then
    echo "  - jq not found, skipping AppManager"
else
    echo "  - Fetching latest AppManager release..."

    API_URL="https://api.github.com/repos/PHNexus/AppManager/releases/latest"
    APPIMAGE_URL=$(curl -fsSL "$API_URL" 2>/dev/null \
        | jq -r '[.assets[]? | select(.name | endswith(".AppImage")) | .browser_download_url][0] // empty' 2>/dev/null || true)

    if [[ -z "$APPIMAGE_URL" || "$APPIMAGE_URL" == "null" ]]; then
        echo "  - Warning: no AppImage found in latest release"
    else
        APPIMAGE_TMP="/tmp/AppManager.AppImage"

        echo "  - Downloading $(basename "$APPIMAGE_URL")..."
        if curl -fsSL "$APPIMAGE_URL" -o "$APPIMAGE_TMP"; then
            chmod +x "$APPIMAGE_TMP"

            echo "  - Installing AppManager..."
            if "$APPIMAGE_TMP" install "$APPIMAGE_TMP" &>/dev/null; then
                echo "  - AppManager installed successfully"
            else
                echo "  - Warning: AppManager self-install failed"
            fi

            rm -f "$APPIMAGE_TMP"

            if ls "$HOME/.local/share/applications" 2>/dev/null | grep -qi "appmanager\|app-manager"; then
                echo "  - Desktop entry registered (should appear in wofi/rofi)"
            fi
        else
            echo "  - Warning: failed to download AppManager"
        fi
    fi
fi

# --------------------------------------------
# Post-install Adjustments
# --------------------------------------------
echo
echo "Applying post-installation adjustments..."

ESCAPED_HOME=$(printf '%s\n' "$HOME" | sed 's/[&|\\]/\\&/g')

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
KEYBINDS_LUA_CONFIG="$CONFIG_DIR/hypr/keybinds.lua"

# --- Gather monitor info ---
# Priority: hyprctl (running Hyprland) -> sysfs (fresh install, no WM yet)
monitor_entries=()

if command -v hyprctl &>/dev/null && command -v jq &>/dev/null && monitors_json="$(hyprctl monitors -j 2>/dev/null)" && jq -e 'type == "array"' >/dev/null <<<"$monitors_json"; then
    echo "  Hyprland is running. Reading active monitors via hyprctl."
    count=$(jq 'length' <<<"$monitors_json")

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
    mapfile -t sorted_entries < <(printf '%s\n' "${sorted_entries[@]}" | sort -t'|' -k1,1 -rn)

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
        
        if [[ ${#monitor_entries[@]} -eq 1 ]]; then
            for w in {1..6}; do
                printf '    hl.workspace_rule({ workspace = %d, monitor = "%s", persistent = true })\n' "$w" "$first_monitor"
            done
        else
            printf '    hl.workspace_rule({ workspace = 1, monitor = "%s", persistent = true })\n' "$first_monitor"
            printf '    hl.workspace_rule({ workspace = 2, monitor = "%s", persistent = true })\n' "$first_monitor"
            printf '    hl.workspace_rule({ workspace = 3, monitor = "%s", persistent = true })\n' "$first_monitor"
            printf '    hl.workspace_rule({ workspace = 4, monitor = "%s", persistent = true })\n' "$first_monitor"
            printf '    hl.workspace_rule({ workspace = 5, monitor = "%s", persistent = true })\n' "$first_monitor"

            if [[ ${#monitor_entries[@]} -ge 2 ]]; then
                second_entry="${monitor_entries[1]}"
                second_monitor="${second_entry%%|*}"
                printf '    hl.workspace_rule({ workspace = 6, monitor = "%s", persistent = true, default = true })\n' "$second_monitor"
            fi
        fi
    fi

    echo "end"
    echo ""
    echo "return M"
} > "$MONITORS_LUA_CONFIG"

if [[ -f "$KEYBINDS_LUA_CONFIG" ]] && [[ ${#monitor_entries[@]} -le 1 ]]; then
perl -0777 -pi -e 's/\n    -- ============================================================\n    -- MOVE WINDOW BETWEEN WORKSPACES \(6 = HDMI\)\n    -- ============================================================\n\n   hl.bind\(mainMod \.\. " \+ R", function\(\).*?end\)\n\n//s' "$KEYBINDS_LUA_CONFIG"
fi

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

WAYBAR_CONFIG=""
for candidate in "$CONFIG_DIR/waybar/config.jsonc" "$CONFIG_DIR/waybar/config" "$CONFIG_DIR/waybar/config.json"; do
    if [[ -f "$candidate" ]]; then
        WAYBAR_CONFIG="$candidate"
        break
    fi
done

if [[ -n "$WAYBAR_CONFIG" ]]; then
    echo "  - Found Waybar config: $WAYBAR_CONFIG"
    if command -v jq >/dev/null 2>&1 && jq empty "$WAYBAR_CONFIG" >/dev/null 2>&1; then
        WAYBAR_TMP="$(mktemp)"
        if [[ -n "${first_monitor:-}" ]]; then
            if jq --arg monitor "$first_monitor" '
                if type == "array" then map(if type == "object" and has("output") then .output = $monitor else . end)
                elif type == "object" then if has("output") then .output = $monitor else . end
                else . end
            ' "$WAYBAR_CONFIG" > "$WAYBAR_TMP"; then
                if jq -e 'if type == "array" then any(.[]; type == "object" and has("output")) elif type == "object" then has("output") else false end' "$WAYBAR_CONFIG" >/dev/null; then
                    cat "$WAYBAR_TMP" > "$WAYBAR_CONFIG"
                    echo "  - Updated Waybar output to detected monitor: $first_monitor."
                else
                    warn "Waybar config has no output field; leaving it unchanged."
                fi
            else
                warn "Could not update Waybar JSON; original file was preserved."
            fi
        else
            if jq 'if type == "array" then map(if type == "object" then del(.output) else . end) elif type == "object" then del(.output) else . end' "$WAYBAR_CONFIG" > "$WAYBAR_TMP"; then
                cat "$WAYBAR_TMP" > "$WAYBAR_CONFIG"
                echo "  - No monitor detected. Removed any hardcoded output from Waybar JSON."
            else
                warn "Could not update Waybar JSON; original file was preserved."
            fi
        fi
        rm -f "$WAYBAR_TMP"
    else
        warn "Waybar config is not valid JSON (it may be JSONC); leaving it unchanged."
    fi
else
    echo "  - No Waybar config found (checked config.jsonc, config and config.json); skipping."
fi
echo "Reloading Hyprland configurations..."
hyprctl reload 2>/dev/null || true

# --------------------------------------------
# Configure EasyEffects systemd user service
# --------------------------------------------
echo
echo "Configuring EasyEffects user service..."

HAS_EASYEFFECTS=0
if [[ -f "$REPO_DIR/packages.txt" ]] && grep -qE '^[[:space:]]*easyeffects[[:space:]]*$' "$REPO_DIR/packages.txt"; then
    HAS_EASYEFFECTS=1
fi

if [[ "$HAS_EASYEFFECTS" -eq 1 ]]; then
    SYSTEMD_USER_DIR="$CONFIG_DIR/systemd/user"
    EASYEFFECTS_SERVICE="$SYSTEMD_USER_DIR/easyeffects.service"

    mkdir -p "$SYSTEMD_USER_DIR"

    cat > "$EASYEFFECTS_SERVICE" <<'EOF'
[Unit]
Description=EasyEffects Service
Wants=pipewire-pulse.service
After=pipewire-pulse.service
BindsTo=pipewire-pulse.service
PartOf=pipewire-pulse.service

[Service]
ExecStart=/usr/bin/easyeffects --gapplication-service
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF

    echo "  - Created EasyEffects service file"

    if command -v systemctl &>/dev/null; then
        if systemctl --user daemon-reload 2>/dev/null && systemctl --user enable --now easyeffects.service 2>/dev/null; then
            echo "  - EasyEffects user service enabled and started."
        else
            echo "  - Warning: could not enable the EasyEffects user service in this session."
        fi
    fi

else
    echo "  - EasyEffects is not listed in packages.txt; skipping its user service."
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
    if flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        if flatpak install --user -y flathub io.github.kolunmi.Bazaar; then
            echo "  - Bazaar installed or already present."
        else
            warn "Bazaar installation failed; continuing with the remaining setup."
        fi
    else
        warn "Could not configure the Flathub user remote; skipping Bazaar."
    fi
else
    echo "  - Flatpak is not installed, skipping Bazaar installation."
fi

# --------------------------------------------
# Install Flatpak Apps from packages.txt
# --------------------------------------------
echo
echo "Configuring Flathub and installing Flatpak apps..."
if command -v flatpak &>/dev/null; then
    if ! flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        warn "Could not configure the Flathub user remote; skipping Flatpak packages."
    elif [[ -f "$REPO_DIR/packages.txt" ]]; then
        # Read and automatically install Flatpaks from the #Flatpaks section in packages.txt
        flatpak_packages=()
        is_flatpaks=0

        while IFS= read -r line || [[ -n "$line" ]]; do
            line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            [[ -z "$line" ]] && continue

            if [[ "$line" =~ ^#[[:space:]]*Flatpaks([[:space:]]|$) ]]; then
                is_flatpaks=1
                continue
            fi

            # Any other section header ends the Flatpak section.
            if [[ "$line" =~ ^# ]]; then
                is_flatpaks=0
                continue
            fi

            [[ "$line" =~ ^# ]] && continue

            if [[ $is_flatpaks -eq 1 ]]; then
                flatpak_packages+=("$line")
            fi
        done < "$REPO_DIR/packages.txt"

        # Install everything listed in the section without prompting
        if [[ ${#flatpak_packages[@]} -gt 0 ]]; then
            for app in "${flatpak_packages[@]}"; do
                echo "  - Installing Flatpak: $app..."
                if ! flatpak install --user -y flathub "$app"; then
                    warn "Failed to install Flatpak '$app'; continuing."
                fi
            done
        fi
    fi
else
    echo "  - Flatpak is not installed, skipping Flatpak applications."
fi

# --------------------------------------------
# Helium DRM Fixer Automation
# --------------------------------------------
if [[ "$HAS_HELIUM_BROWSER" -eq 1 ]]; then
    echo
    echo "Starting Helium DRM Fixer setup..."

# Install bun
sudo pacman -S --needed --noconfirm bun

# Prepare temporary directory
HELIUM_DRM_DIR="/tmp/helium-drm-fixer"
CHROME_WAS_INSTALLED=0
CHROME_INSTALLED_BY_SCRIPT=0

if pacman -Qi google-chrome &>/dev/null; then
    CHROME_WAS_INSTALLED=1
fi

cleanup_helium_drm() {
    if [[ -n "${HELIUM_DRM_DIR:-}" ]]; then
        rm -rf -- "$HELIUM_DRM_DIR"
    fi

    if [[ "$CHROME_INSTALLED_BY_SCRIPT" -eq 1 ]]; then
        sudo pacman -Rns --noconfirm google-chrome &>/dev/null || true
        if [[ "$AUR_HELPER" == "yay" ]]; then
            rm -rf "$HOME/.cache/yay/google-chrome"
        elif [[ "$AUR_HELPER" == "paru" ]]; then
            rm -rf "$HOME/.cache/paru/clone/google-chrome"
        fi
    fi
}
trap cleanup_helium_drm EXIT

rm -rf "$HELIUM_DRM_DIR"
if ! git clone https://github.com/PHNexus/helium-drm-fixer.git "$HELIUM_DRM_DIR"; then
    warn "Could not clone Helium DRM Fixer; skipping this optional step."
    HELIUM_DRM_DIR=""
fi

if [[ -z "$HELIUM_DRM_DIR" || ! -d "$HELIUM_DRM_DIR" ]]; then
    echo "  - Helium DRM Fixer unavailable; continuing without running it."
else
echo "Installing Google Chrome temporarily via $AUR_HELPER..."
if [[ "$CHROME_WAS_INSTALLED" -eq 0 ]]; then
    CHROME_INSTALLED_BY_SCRIPT=1
    # Feed the package transaction confirmation explicitly: some yay/pacman
    # combinations still show the transaction prompt despite --noconfirm.
    if ! printf 'Y\n' | aur_install google-chrome; then
        CHROME_INSTALLED_BY_SCRIPT=0
        warn "Could not install temporary Google Chrome; skipping the DRM fixer run."
    fi
else
    echo "  - Google Chrome is already installed. Keeping the existing installation."
fi

# Run the DRM fix
cd "$HELIUM_DRM_DIR"
if ! bun install || ! bun run cli.ts; then
    warn "Helium DRM Fixer failed; continuing with the remaining installer steps."
fi

if [[ "$CHROME_INSTALLED_BY_SCRIPT" -eq 1 ]]; then
    echo "Uninstalling temporary Google Chrome..."
    # Remove only the temporary package; leave browser profile data untouched.
    # Explicit stdin confirmation covers pacman builds that still prompt despite --noconfirm.
    if ! printf 'Y\n' | sudo pacman -Rns --noconfirm google-chrome; then
        warn "Could not remove temporary Google Chrome automatically."
    fi
    if [[ "$AUR_HELPER" == "yay" ]]; then
        rm -rf "$HOME/.cache/yay/google-chrome"
    elif [[ "$AUR_HELPER" == "paru" ]]; then
        rm -rf "$HOME/.cache/paru/clone/google-chrome"
    fi
else
    echo "  - Existing Google Chrome installation was left untouched."
fi

# Clean up the temporary fixer repository.
rm -rf "$HELIUM_DRM_DIR"
trap - EXIT
cd "$REPO_DIR"
fi
    echo "Helium DRM Fixer step finished."

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
else
    echo
    echo "Skipping Helium browser configuration: helium-browser-bin is not listed in packages.txt."
fi

# --------------------------------------------
# Install and Configure GameMode
# --------------------------------------------
echo
echo "Installing and configuring GameMode..."

# 1. Install GameMode and 32-bit support
sudo pacman -S --needed --noconfirm gamemode lib32-gamemode

# 2. Test GameMode instead of enabling a service that may not exist. The
# daemon is normally activated on demand over D-Bus when a game requests it.
if command -v gamemoded >/dev/null 2>&1; then
    if gamemoded -t; then
        echo "  - GameMode diagnostic test passed."
    else
        warn "GameMode diagnostic test failed; inspect the output above before relying on it."
    fi
else
    warn "gamemoded was not found after package installation."
fi

# 3. Download default configuration file from official repository
if [[ ! -f "$CONFIG_DIR/gamemode.ini" ]]; then
    if command -v curl >/dev/null 2>&1 && curl -fsSL https://raw.githubusercontent.com/FeralInteractive/gamemode/master/example/gamemode.ini -o "$CONFIG_DIR/gamemode.ini"; then
        echo "  - Downloaded default gamemode.ini to $CONFIG_DIR/"
    else
        rm -f "$CONFIG_DIR/gamemode.ini"
        warn "Could not download the default gamemode.ini; continuing."
    fi
fi

echo "GameMode package/configuration step finished; see diagnostic result above."

# --------------------------------------------
# Configure cpupower for Performance mode
# --------------------------------------------
HAS_CPUPOWER=0
if [[ -f "$REPO_DIR/packages.txt" ]] && grep -qE '^[[:space:]]*cpupower[[:space:]]*$' "$REPO_DIR/packages.txt"; then
    HAS_CPUPOWER=1
fi

if [[ "$HAS_CPUPOWER" -eq 1 ]]; then
    echo
    echo "Configuring cpupower for Performance mode..."
    if [[ -f /etc/default/cpupower-service.conf ]]; then
        sudo sed -i '/GOVERNOR/d' /etc/default/cpupower-service.conf
        echo 'GOVERNOR="performance"' | sudo tee -a /etc/default/cpupower-service.conf > /dev/null
        if sudo systemctl enable --now cpupower.service; then
            echo "  - cpupower service enabled with 'performance' governor."
        else
            warn "Could not enable cpupower.service; the configuration file was updated."
        fi
    else
        echo "  - cpupower-service.conf not found, skipping."
    fi
else
    echo "  - cpupower is not listed in packages.txt; skipping configuration."
fi

# --------------------------------------------
# Configure Cloudflare WARP
# --------------------------------------------
if [[ "$HAS_CLOUDFLARE_WARP" -eq 1 ]]; then
    echo
    echo "Configuring Cloudflare WARP..."

# Enable and start the WARP background service
if command -v systemctl &>/dev/null; then
    if sudo systemctl enable --now warp-svc; then
        echo "  - warp-svc service enabled and started."
    else
        warn "Could not enable warp-svc; WARP CLI configuration may not work."
    fi
    
    # Wait a few seconds for the daemon to fully initialize
    sleep 3
fi

# Preserve an existing registration. Never delete/recreate it automatically:
# doing so can invalidate the account/device registration already on this machine.
if command -v warp-cli &>/dev/null; then
    if warp-cli registration show >/dev/null 2>&1; then
        echo "  - Existing Cloudflare WARP registration found; keeping it."
    elif warp-cli --accept-tos registration new; then
        echo "  - Cloudflare WARP registration created (not connected)."
    else
        warn "Could not verify or create a WARP registration; existing data was not deleted."
    fi

    if warp-cli mode warp+doh; then
        echo "  - WARP mode set to warp+doh."
    else
        echo "  Warning: failed to set WARP mode to warp+doh."
    fi
else
    echo "  - warp-cli not found, skipping configuration."
fi
else
    echo
    echo "Skipping Cloudflare WARP configuration: cloudflare-warp-bin is not listed in packages.txt."
fi

# --------------------------------------------
# Remove NVIDIA environment variables if NVIDIA is NOT detected
# --------------------------------------------
echo
echo "Checking GPU vendor to adjust Hyprland environment variables..."

ENV_LUA_FILE="$HOME/.config/hypr/environment.lua"

if ! command -v lspci >/dev/null 2>&1; then
    warn "lspci is unavailable; leaving NVIDIA environment variables unchanged. Install pciutils to enable GPU detection."
elif lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' | grep -iEq 'nvidia'; then
    echo "  - NVIDIA GPU detected, keeping original environment variables."
else
    echo "  - No NVIDIA GPU detected. Removing NVIDIA environment variables..."
    if [[ -f "$ENV_LUA_FILE" ]]; then
        sed -i -E '/(LIBVA_DRIVER_NAME|__GLX_VENDOR_LIBRARY_NAME|GBM_BACKEND|NVD_BACKEND|VDPAU_DRIVER|__GL_SHADER_DISK_CACHE|__GL_SYNC_TO_VBLANK)/I d' "$ENV_LUA_FILE"
        sed -i '/-- NVIDIA/d' "$ENV_LUA_FILE"
        echo "  - NVIDIA environment variables removed from environment.lua."
    else
        warn "$ENV_LUA_FILE not found; skipping GPU environment adjustment."
    fi
fi

# --------------------------------------------
# Install MacTahoe Icon Theme
# --------------------------------------------
echo
echo "Installing MacTahoe icon theme..."

MACOS_ICON_DIR="$(mktemp -d /tmp/MacTahoe-icon-theme.XXXXXX)"
MACOS_ICON_READY=0
MACOS_ICON_URL="https://github.com/PHNexus/MacTahoe-icon-theme.git"

# Retry shallow clone; if Git transport is unavailable, try GitHub's source archive.
for attempt in 1 2 3; do
    rm -rf "$MACOS_ICON_DIR"/* "$MACOS_ICON_DIR"/.[!.]* "$MACOS_ICON_DIR"/..?* 2>/dev/null || true
    if git -c http.connectTimeout=15 clone --depth=1 "$MACOS_ICON_URL" "$MACOS_ICON_DIR"; then
        MACOS_ICON_READY=1
        break
    fi
    warn "MacTahoe clone attempt $attempt/3 failed."
    [[ "$attempt" -eq 3 ]] || sleep 2
done

if [[ "$MACOS_ICON_READY" -eq 0 ]] && command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    MACOS_ICON_ARCHIVE="$(mktemp /tmp/MacTahoe-icon-theme.XXXXXX.tar.gz)"
    if curl -fL --retry 2 --retry-delay 2 --connect-timeout 15 --max-time 180 \
        "https://codeload.github.com/PHNexus/MacTahoe-icon-theme/tar.gz/refs/heads/main" \
        -o "$MACOS_ICON_ARCHIVE"; then
        if tar -xzf "$MACOS_ICON_ARCHIVE" --strip-components=1 -C "$MACOS_ICON_DIR"; then
            MACOS_ICON_READY=1
        fi
    fi
    rm -f "$MACOS_ICON_ARCHIVE"
fi

MACOS_ICON_INSTALLED=0
if [[ "$MACOS_ICON_READY" -eq 1 && -f "$MACOS_ICON_DIR/install.sh" ]]; then
    if (cd "$MACOS_ICON_DIR" && bash ./install.sh); then
        if [[ -d "$HOME/.local/share/icons/MacTahoe" ]]; then
            MACOS_ICON_INSTALLED=1
            echo "  - Installed MacTahoe icon theme."
        else
            warn "MacTahoe installer exited successfully, but the expected theme directory was not found."
        fi
    else
        warn "MacTahoe upstream installer failed."
    fi
else
    warn "Could not download MacTahoe icon theme; skipping it without affecting the rest of setup."
fi

rm -rf "$MACOS_ICON_DIR"

# --------------------------------------------
# Configure GTK and Icon Themes (GNOME)
# --------------------------------------------
echo
echo "Applying GTK and icon themes..."
if command -v gsettings >/dev/null 2>&1; then
    theme_changes_ok=1
    gsettings set org.gnome.desktop.interface gtk-theme "Materia-dark-compact" || theme_changes_ok=0
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || theme_changes_ok=0

    if [[ "$MACOS_ICON_INSTALLED" -eq 1 ]]; then
        if [[ -d "$HOME/.local/share/icons/MacTahoe-nord-dark" ]]; then
            gsettings set org.gnome.desktop.interface icon-theme "MacTahoe" || theme_changes_ok=0
        else
            gsettings set org.gnome.desktop.interface icon-theme "MacTahoe" || theme_changes_ok=0
        fi
    else
        echo "  - MacTahoe was not installed; leaving the current icon theme unchanged."
    fi

    if [[ "$theme_changes_ok" -eq 1 ]]; then
        echo "  - Available GTK/dark-mode settings applied."
    else
        warn "One or more theme settings could not be applied in this desktop session."
    fi
else
    warn "gsettings is unavailable; skipping GTK and icon theme settings."
fi

# --------------------------------------------
# Configure Cloudflare DNS (1.1.1.1)
# --------------------------------------------
if [[ "$HAS_CLOUDFLARE_WARP" -eq 1 ]]; then
    echo
    echo "Configuring Cloudflare DNS..."

# Ensure NetworkManager is running before using nmcli
if command -v systemctl &>/dev/null; then
    sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
fi

# Automatically discover the active ethernet/network connection name
if command -v nmcli &>/dev/null; then
    ACTIVE_CONN=$(nmcli -t -f NAME,DEVICE connection show --active | grep -v ':lo$' | head -n1 | cut -d: -f1 || true)

    if [[ -n "$ACTIVE_CONN" ]]; then
        if sudo nmcli connection modify "$ACTIVE_CONN" ipv4.dns "1.1.1.1,1.0.0.1" && \
           sudo nmcli connection modify "$ACTIVE_CONN" ipv4.ignore-auto-dns yes && \
           sudo nmcli connection up "$ACTIVE_CONN"; then
            echo "  - DNS updated to Cloudflare on connection: $ACTIVE_CONN"
        else
            warn "Could not apply Cloudflare DNS to connection: $ACTIVE_CONN"
        fi
    else
        echo "  - No active network connection found to update DNS."
    fi
else
    echo "  - NetworkManager/nmcli not found, skipping Cloudflare DNS configuration."
fi
else
    echo
    echo "Skipping Cloudflare DNS configuration: cloudflare-warp-bin is not listed in packages.txt."
fi

# --------------------------------------------
# Set Fish as Default Shell
# --------------------------------------------
echo
echo "Setting fish as the default shell..."
if command -v fish &>/dev/null; then
    FISH_PATH="$(command -v fish)"

    if ! grep -qxF "$FISH_PATH" /etc/shells; then
        echo "$FISH_PATH" | sudo tee -a /etc/shells > /dev/null
    fi

    CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"

    if [[ "$CURRENT_SHELL" == "$FISH_PATH" ]]; then
        echo "  - Fish is already the default shell."
    elif sudo chsh -s "$FISH_PATH" "$USER"; then
        NEW_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
        if [[ "$NEW_SHELL" == "$FISH_PATH" ]]; then
            echo "  - Default shell changed to fish."
        else
            echo "  Warning: chsh completed, but the default shell could not be verified."
        fi
    else
        echo "  Warning: failed to change the default shell to fish."
    fi
else
    echo "  - Fish is not installed, skipping."
fi

echo
echo "Installer reached the end. Review any warnings above for components that were skipped or need attention."
echo "Reloading Hyprland configurations..."
hyprctl reload 2>/dev/null || true
read -rp "Would you like to reboot now? [Y/n]: " reboot_choice
reboot_choice="${reboot_choice:-Y}"

if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    sudo reboot
fi