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
        -h | --help)
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
BANNER_BORDER='\033[38;5;130m'
BANNER_ACCENT='\033[38;5;166m'
BANNER_PRIMARY='\033[38;5;172m'
BANNER_TEXT='\033[38;5;255m'
BANNER_MUTED='\033[38;5;245m'
BANNER_WARNING='\033[38;5;202m'
BANNER_RESET='\033[0m'
BANNER_WIDTH=70

banner_rule() {
    local left="$1" right="$2" fill="$3" line="" column
    for ((column = 0; column < BANNER_WIDTH; column++)); do
        line+="$fill"
    done
    printf '%b\n' "${BANNER_BORDER}${left}${line}${right}${BANNER_RESET}"
}

banner_row() {
    local plain_text="$1" styled_text="$2"
    local padding=$((BANNER_WIDTH - ${#plain_text}))
    ((padding < 0)) && padding=0
    printf '%b' "${BANNER_BORDER}│${BANNER_RESET}"
    printf '%b' "$styled_text"
    printf '%*s' "$padding" ''
    printf '%b\n' "${BANNER_BORDER}│${BANNER_RESET}"
}

draw_setup_banner() {
    local title='  ⚙  HYPRLAND RICE  ·  INSTALLER'

    banner_rule '╭' '╮' '─'
    banner_row "$title" "${BANNER_ACCENT}${title}${BANNER_RESET}"
    banner_rule '├' '┤' '─'
    banner_row '  ◈  Fresh Arch Linux installation recommended' "${BANNER_PRIMARY}  ◈${BANNER_RESET}  ${BANNER_TEXT}Fresh Arch Linux installation recommended${BANNER_RESET}"
    banner_row '  ▣  Backs up ~/.config to ~/.config/backups/' "${BANNER_PRIMARY}  ▣${BANNER_RESET}  ${BANNER_TEXT}Backs up ${BANNER_ACCENT}~/.config${BANNER_TEXT} to ${BANNER_ACCENT}~/.config/backups/${BANNER_RESET}"
    banner_row '  ◉  Installs required packages and selected optional apps' "${BANNER_PRIMARY}  ◉${BANNER_RESET}  ${BANNER_TEXT}Installs required packages and selected optional apps${BANNER_RESET}"
    banner_row '  ⌁  Removes htop, vim and dolphin; sets Fish as shell' "${BANNER_PRIMARY}  ⌁${BANNER_RESET}  ${BANNER_TEXT}Removes htop, vim and dolphin; sets ${BANNER_ACCENT}Fish${BANNER_TEXT} as shell${BANNER_RESET}"
    banner_row '  ◇  Helium DRM setup runs only when Helium is selected' "${BANNER_PRIMARY}  ◇${BANNER_RESET}  ${BANNER_TEXT}Helium DRM setup runs only when Helium is selected${BANNER_RESET}"
    banner_row '  ▦  Detects monitors and configures Hyprland workspaces' "${BANNER_PRIMARY}  ▦${BANNER_RESET}  ${BANNER_TEXT}Detects monitors and configures Hyprland workspaces${BANNER_RESET}"
    banner_row '  ◈  Installs Dock Bar (Quickshell) and Hyprquickpaper' "${BANNER_PRIMARY}  ◈${BANNER_RESET}  ${BANNER_TEXT}Installs Dock Bar (Quickshell) and Hyprquickpaper${BANNER_RESET}"
    banner_row '  ▸  Removes NVIDIA variables on AMD/Intel systems' "${BANNER_PRIMARY}  ▸${BANNER_RESET}  ${BANNER_TEXT}Removes NVIDIA variables on AMD/Intel systems${BANNER_RESET}"
    banner_rule '├' '┤' '─'
    banner_row '  !  Review the script before running; reboot required' "${BANNER_WARNING}  !${BANNER_RESET}  ${BANNER_WARNING}Review the script before running; reboot required${BANNER_RESET}"
    banner_rule '╰' '╯' '─'
}

draw_setup_banner
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
# Configure Bluetooth only when relevant
# --------------------------------------------
bluetooth_module_service_exists() {
    if command -v systemctl >/dev/null 2>&1 &&
        systemctl cat bluetooth.service >/dev/null 2>&1; then
        return 0
    fi

    [[ -e /usr/lib/systemd/system/bluetooth.service ||
        -e /etc/systemd/system/bluetooth.service ||
        -e /lib/systemd/system/bluetooth.service ]]
}

bluetooth_module_adapter_detected() {
    local controller usb_iface interface_class interface_subclass

    # Most reliable signal: the kernel has registered a Bluetooth controller.
    for controller in /sys/class/bluetooth/hci*; do
        [[ -e "$controller" ]] && return 0
    done

    # Covers USB adapters already bound to the standard Linux btusb driver,
    # including models with vendor-specific USB IDs.
    for usb_iface in /sys/bus/usb/drivers/btusb/*:*; do
        [[ -e "$usb_iface" ]] && return 0
    done

    # Also catch class-compliant USB Bluetooth interfaces before an HCI
    # controller appears, so BlueZ can be installed/configured when needed.
    for usb_iface in /sys/bus/usb/devices/*:*; do
        [[ -r "$usb_iface/bInterfaceClass" &&
            -r "$usb_iface/bInterfaceSubClass" ]] || continue

        interface_class="$(< "$usb_iface/bInterfaceClass")"
        interface_subclass="$(< "$usb_iface/bInterfaceSubClass")"

        if [[ "${interface_class,,}" == "e0" &&
            "${interface_subclass,,}" == "01" ]]; then
            return 0
        fi
    done

    return 1
}

configure_bluetooth_module() {
    local has_service=0
    local has_adapter=0

    bluetooth_module_service_exists && has_service=1 || true
    bluetooth_module_adapter_detected && has_adapter=1 || true

    if [[ "$has_service" -eq 0 && "$has_adapter" -eq 0 ]]; then
        echo
        echo "Bluetooth: no service or recognized adapter found; skipping configuration."
        return 0
    fi

    echo
    echo "Configuring Bluetooth (service found: $has_service; adapter found: $has_adapter)..."

    # BlueZ provides bluetooth.service. Install it only after the detection gate.
    if ! pacman -Q bluez bluez-utils >/dev/null 2>&1; then
        if ! sudo pacman -S --needed --noconfirm bluez bluez-utils; then
            warn "Could not install BlueZ; skipping the Bluetooth configuration."
            return 0
        fi
    fi

    if ! bluetooth_module_service_exists; then
        warn "BlueZ packages are installed, but bluetooth.service was not found; skipping further changes."
        return 0
    fi

    local conf="/etc/bluetooth/main.conf"
    local conf_tmp conf_updated conf_backup
    conf_tmp="$(mktemp)"
    conf_updated="$(mktemp)"

    if [[ -f "$conf" ]]; then
        if ! sudo cat "$conf" > "$conf_tmp"; then
            rm -f "$conf_tmp" "$conf_updated"
            warn "Could not read $conf; skipping Bluetooth config edits."
            return 0
        fi
    else
        : > "$conf_tmp"
    fi

    # Preserve existing settings. ControllerMode stays at bredr as requested;
    # FastConnectable belongs in [General] and AutoEnable belongs in [Policy].
    if ! awk '
        function add_general() {
            if (!general_written) {
                print "ControllerMode = bredr"
                print "FastConnectable = true"
                general_written = 1
            }
        }
        function add_policy() {
            if (!policy_written) {
                print "AutoEnable = true"
                policy_written = 1
            }
        }
        /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
            if (section == "General") add_general()
            if (section == "Policy") add_policy()
            section = $0
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\][[:space:]]*$/, "", section)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", section)
            if (section == "General") seen_general = 1
            if (section == "Policy") seen_policy = 1
            print
            next
        }
        section == "General" && /^[[:space:]]*(ControllerMode|FastConnectable)[[:space:]]*=/ { next }
        section == "Policy" && /^[[:space:]]*AutoEnable[[:space:]]*=/ { next }
        { print }
        END {
            if (section == "General") add_general()
            if (section == "Policy") add_policy()
            if (!seen_general) {
                print ""
                print "[General]"
                add_general()
            }
            if (!seen_policy) {
                print ""
                print "[Policy]"
                add_policy()
            }
        }
    ' "$conf_tmp" > "$conf_updated"; then
        rm -f "$conf_tmp" "$conf_updated"
        warn "Could not prepare $conf; skipping Bluetooth config edits."
        return 0
    fi

    if [[ ! -f "$conf" ]] || ! cmp -s "$conf_updated" "$conf"; then
        if [[ -f "$conf" ]]; then
            conf_backup="${conf}.backup-$(date +%Y%m%d-%H%M%S)"
            if ! sudo cp -a "$conf" "$conf_backup"; then
                rm -f "$conf_tmp" "$conf_updated"
                warn "Could not back up $conf; leaving it unchanged."
                return 0
            fi
            echo "  - Backed up main.conf to $conf_backup"
        fi

        if ! sudo install -D -o root -g root -m 0644 "$conf_updated" "$conf"; then
            rm -f "$conf_tmp" "$conf_updated"
            warn "Could not install updated $conf."
            return 0
        fi
        echo "  - Configured AutoEnable=true, ControllerMode=bredr and FastConnectable=true."
    else
        echo "  - main.conf already has the desired Bluetooth settings."
    fi
    rm -f "$conf_tmp" "$conf_updated"

    # Do not hard-code a USB vendor/product ID. These rules match USB
    # interfaces handled by btusb and standard Bluetooth-class interfaces.
    # This keeps the power-management rule usable across different dongles.
    local rule="/etc/udev/rules.d/50-bluetooth.rules"
    local rule_line usb_iface
    local -a rule_lines=(
        'ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", DRIVER=="btusb", TEST=="power/control", ATTR{power/control}="on"'
        'ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="e0", ATTR{bInterfaceSubClass}=="01", TEST=="power/control", ATTR{power/control}="on"'
    )

    if ! sudo test -f "$rule"; then
        if ! sudo install -D -o root -g root -m 0644 /dev/null "$rule"; then
            warn "Could not create $rule; continuing with the service setup."
        fi
    fi

    if sudo test -f "$rule"; then
        for rule_line in "${rule_lines[@]}"; do
            if ! sudo grep -Fqx -- "$rule_line" "$rule"; then
                if printf '%s\n' "$rule_line" | sudo tee -a "$rule" >/dev/null; then
                    echo "  - Added a generic Bluetooth USB power rule to $rule."
                else
                    warn "Could not add a USB rule to $rule."
                fi
            fi
        done
    fi

    if command -v udevadm >/dev/null 2>&1; then
        sudo udevadm control --reload-rules || warn "Could not reload udev rules."

        # Re-apply only to interfaces already bound to btusb; avoid retriggering
        # unrelated USB devices. New adapters will match when plugged in.
        for usb_iface in /sys/bus/usb/drivers/btusb/*:*; do
            [[ -e "$usb_iface" ]] || continue
            if sudo test -e "$usb_iface/power/control"; then
                if ! printf 'on\n' | sudo tee "$usb_iface/power/control" >/dev/null; then
                    warn "Could not set USB power control for $usb_iface."
                fi
            fi
            sudo udevadm trigger --action=add "$usb_iface" 2>/dev/null || true
        done

        # This selector is limited to standard Bluetooth-class USB interfaces.
        sudo udevadm trigger --action=add --subsystem-match=usb \
            --attr-match=bInterfaceClass=e0 --attr-match=bInterfaceSubClass=01 \
            2>/dev/null || true
    fi

    echo "options btusb enable_autosuspend=0" | sudo tee /etc/modprobe.d/btusb.conf >/dev/null

    if command -v systemctl >/dev/null 2>&1; then
        if sudo systemctl enable --now bluetooth.service; then
            echo "  - bluetooth.service enabled and started."
        else
            warn "Could not enable/start bluetooth.service."
        fi
    else
        warn "systemctl was not found; could not enable bluetooth.service."
    fi
}

configure_bluetooth_module


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

OPTIONAL_PACKAGE_NAMES=(
    steam
    easyeffects
    spotify
    visual-studio-code-bin
    helium-browser-bin
    github-desktop-bin
    bitwarden-bin
    artcraft-launcher
)

declare -A OPTIONAL_DESCRIPTIONS=(
    [artcraft-launcher]="Free, open-source Adobe alternatives"
)
declare -A OPTIONAL_DISPLAY_NAMES=(
    [artcraft-launcher]="ArtCraft Launcher"
)
declare -A OPTIONAL_NAME_SET=()
declare -A SEEN_PACKAGES=()
declare -A PACKAGE_SOURCE=()
declare -A SELECTED_OPTIONAL=()
declare -A INSTALLED_OPTIONAL=()

official_packages=()
aur_packages=()
flatpak_packages=()
optional_packages=()

for package in "${OPTIONAL_PACKAGE_NAMES[@]}"; do
    OPTIONAL_NAME_SET["$package"]=1
done

PACKAGE_SECTION="official"

if [[ -f "$REPO_DIR/packages.txt" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue

        if [[ "${line,,}" =~ ^#[[:space:]]*aur([[:space:]]|$) ]]; then
            PACKAGE_SECTION="aur"
            continue
        fi

        if [[ "${line,,}" =~ ^#[[:space:]]*flatpaks?([[:space:]]|$) ]]; then
            PACKAGE_SECTION="flatpak"
            continue
        fi

        [[ "$line" =~ ^# ]] && continue
        [[ -n "${SEEN_PACKAGES["$line"]:-}" ]] && continue

        SEEN_PACKAGES["$line"]=1
        PACKAGE_SOURCE["$line"]="$PACKAGE_SECTION"

        if [[ -n "${OPTIONAL_NAME_SET["$line"]:-}" ]]; then
            if [[ "$line" == "artcraft-launcher" ]]; then
                PACKAGE_SOURCE["$line"]="custom"
            fi
            optional_packages+=("$line")
            continue
        fi

        case "$PACKAGE_SECTION" in
            official) official_packages+=("$line") ;;
            aur) aur_packages+=("$line") ;;
            flatpak) flatpak_packages+=("$line") ;;
        esac
    done < "$REPO_DIR/packages.txt"
else
    echo "packages.txt not found in repository root."
fi

if [[ -z "${SEEN_PACKAGES["artcraft-launcher"]:-}" ]]; then
    optional_packages+=("artcraft-launcher")
    PACKAGE_SOURCE["artcraft-launcher"]="custom"
fi

MENU_BORDER=$'\033[38;5;130m'
MENU_ACCENT=$'\033[38;5;166m'
MENU_PRIMARY=$'\033[38;5;172m'
MENU_TEXT=$'\033[38;5;255m'
MENU_MUTED=$'\033[38;5;245m'
MENU_RESET=$'\033[0m'

optional_source_marker() {
    case "$1" in
        official) printf '●' ;;
        aur) printf '◆' ;;
        flatpak) printf '⬡' ;;
        custom) printf '✦' ;;
        *) printf '·' ;;
    esac
}

optional_source_label() {
    case "$1" in
        official) printf 'PACMAN' ;;
        aur) printf 'AUR' ;;
        flatpak) printf 'FLATPAK' ;;
        custom) printf 'APPIMAGE' ;;
        *) printf 'UNKNOWN' ;;
    esac
}

menu_print_rule() {
    local left="$1" right="$2" fill="$3" line="" column
    for ((column = 0; column < menu_width; column++)); do
        line+="$fill"
    done
    printf '%b\n' "${MENU_BORDER}${left}${line}${right}${MENU_RESET}"
}

menu_print_row() {
    local plain_text="$1" styled_text="$2"
    local padding=$((menu_width - ${#plain_text}))
    ((padding < 0)) && padding=0
    printf '%b' "${MENU_BORDER}│${MENU_RESET}"
    printf '%b' "$styled_text"
    printf '%*s' "$padding" ''
    printf '%b\n' "${MENU_BORDER}│${MENU_RESET}"
}

menu_print_package() {
    local number="$1" package="$2" source="$3"
    local marker label display_name plain_text padding
    marker="$(optional_source_marker "$source")"
    label="$(optional_source_label "$source")"
    display_name="${OPTIONAL_DISPLAY_NAMES[$package]:-$package}"
    printf -v plain_text '  %2d  %s %-*s  %s' \
        "$number" "$marker" "$package_width" "$display_name" "$label"
    padding=$((menu_width - ${#plain_text}))
    ((padding < 0)) && padding=0

    printf '%b' "${MENU_BORDER}│${MENU_RESET}"
    printf '%b' "${MENU_MUTED}  ${MENU_RESET}${MENU_PRIMARY}"
    printf '%2d' "$number"
    printf '%b' "${MENU_RESET}  ${MENU_ACCENT}${marker}${MENU_RESET} ${MENU_TEXT}"
    printf '%-*s' "$package_width" "$display_name"
    printf '%b' "${MENU_RESET}  ${MENU_MUTED}${label}${MENU_RESET}"
    printf '%*s' "$padding" ''
    printf '%b\n' "${MENU_BORDER}│${MENU_RESET}"
}

draw_optional_menu() {
    local LC_ALL=C.UTF-8
    local package i title subtitle legend marker display_name description package_width=0 menu_width=60
    for package in "${optional_packages[@]}"; do
        display_name="${OPTIONAL_DISPLAY_NAMES[$package]:-$package}"
        (( ${#display_name} > package_width )) && package_width=${#display_name}
        description="${OPTIONAL_DESCRIPTIONS[$package]:-}"
        if [[ -n "$description" ]] && (( ${#description} + 10 > menu_width )); then
            menu_width=$((${#description} + 10))
        fi
    done
    ((package_width + 17 > menu_width)) && menu_width=$((package_width + 17))

    menu_print_rule '╭' '╮' '─'
    title='  ◈  OPTIONAL SOFTWARE'
    menu_print_row "$title" "${MENU_ACCENT}${title}${MENU_RESET}"

    subtitle='  Choose which applications to include in this setup.'
    menu_print_row "$subtitle" "${MENU_TEXT}  Choose which applications to include in this setup.${MENU_RESET}"

    legend='  ● PACMAN     ◆ AUR     ⬡ FLATPAK     ✦ APPIMAGE'
    menu_print_row "$legend" "${MENU_PRIMARY}  ●${MENU_RESET} ${MENU_MUTED}PACMAN${MENU_RESET}     ${MENU_ACCENT}◆${MENU_RESET} ${MENU_MUTED}AUR${MENU_RESET}     ${MENU_PRIMARY}⬡${MENU_RESET} ${MENU_MUTED}FLATPAK${MENU_RESET}     ${MENU_ACCENT}✦${MENU_RESET} ${MENU_MUTED}APPIMAGE${MENU_RESET}"
    menu_print_rule '├' '┤' '─'

    for i in "${!optional_packages[@]}"; do
        package="${optional_packages[$i]}"
        menu_print_package "$((i + 1))" "$package" "${PACKAGE_SOURCE[$package]}"
        description="${OPTIONAL_DESCRIPTIONS[$package]:-}"
        if [[ -n "$description" ]]; then
            menu_print_row "       ↳ $description" "       ${MENU_MUTED}↳ ${MENU_TEXT}${description}${MENU_RESET}"
        fi
    done

    menu_print_rule '├' '┤' '─'
    menu_print_row '  ↳  Enter or 0   Skip optional applications' "${MENU_ACCENT}  ↳${MENU_RESET}  ${MENU_TEXT}Enter or 0   Skip optional applications${MENU_RESET}"
    menu_print_row '  ↳  all           Select every application' "${MENU_ACCENT}  ↳${MENU_RESET}  ${MENU_TEXT}all           Select every application${MENU_RESET}"
    menu_print_row '  Example: 1 3 5  or  2,4,7' "${MENU_MUTED}  Example: ${MENU_TEXT}1 3 5${MENU_MUTED}  or  ${MENU_TEXT}2,4,7${MENU_RESET}"
    menu_print_rule '╰' '╯' '─'
}

read_optional_selection() {
    local selection_input number number_value package valid_selection selected_count
    local -a selections=()
    local -A seen_numbers=()

    while true; do
        printf '%b' "${MENU_ACCENT}  ❯ ${MENU_RESET}"
        if ! IFS= read -r selection_input; then
            selection_input=""
        fi

        selection_input="${selection_input//,/ }"
        selections=()
        read -r -a selections <<< "$selection_input"

        if [[ ${#selections[@]} -eq 0 ]]; then
            printf '%b\n' "${MENU_MUTED}  No optional applications selected.${MENU_RESET}"
            break
        fi

        if [[ ${#selections[@]} -eq 1 && "${selections[0],,}" == "all" ]]; then
            for package in "${optional_packages[@]}"; do
                SELECTED_OPTIONAL["$package"]=1
            done
            printf '%b\n' "${MENU_PRIMARY}  ✓ All optional applications selected.${MENU_RESET}"
            break
        fi

        if [[ ${#selections[@]} -eq 1 && "${selections[0]}" == "0" ]]; then
            printf '%b\n' "${MENU_MUTED}  No optional applications selected.${MENU_RESET}"
            break
        fi

        seen_numbers=()
        valid_selection=1

        for number in "${selections[@]}"; do
            if [[ ! "$number" =~ ^[1-9][0-9]*$ ]]; then
                valid_selection=0
                break
            fi

            number_value=$((10#$number))
            if (( number_value < 1 || number_value > ${#optional_packages[@]} )); then
                valid_selection=0
                break
            fi

            seen_numbers["$number_value"]=1
        done

        if [[ "$valid_selection" -ne 1 ]]; then
            printf '%b\n' "${MENU_ACCENT}  × Invalid selection. Enter valid numbers, 0 or all.${MENU_RESET}"
            continue
        fi

        for number in "${!seen_numbers[@]}"; do
            package="${optional_packages[$((number - 1))]}"
            SELECTED_OPTIONAL["$package"]=1
        done

        selected_count=${#seen_numbers[@]}
        printf '%b\n' "${MENU_PRIMARY}  ✓ Selected ${selected_count} optional application(s).${MENU_RESET}"
        break
    done
}

if [[ ${#optional_packages[@]} -gt 0 ]]; then
    echo
    draw_optional_menu
    read_optional_selection
fi

if [[ ${#official_packages[@]} -gt 0 ]]; then
    echo "Installing required official packages via pacman..."
    sudo pacman -S --needed --noconfirm "${official_packages[@]}"
fi

if [[ ${#aur_packages[@]} -gt 0 ]]; then
    echo "Installing required AUR packages via $AUR_HELPER..."
    aur_install "${aur_packages[@]}"
fi

FLATPAK_READY=0
if command -v flatpak >/dev/null 2>&1; then
    if flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        FLATPAK_READY=1
    else
        warn "Could not configure Flathub; Flatpak installations may be skipped."
    fi
else
    echo "  - Flatpak is not installed; Flatpak applications will be skipped."
fi

for package in "${flatpak_packages[@]}"; do
    if [[ "$FLATPAK_READY" -eq 1 ]]; then
        echo "Installing required Flatpak: $package..."
        if ! flatpak install --user -y flathub "$package"; then
            warn "Failed to install Flatpak '$package'; continuing."
        fi
    else
        warn "Cannot install Flatpak '$package' because Flatpak or Flathub is unavailable."
    fi
done

install_optional_package() {
    local package="$1"
    local source="${PACKAGE_SOURCE["$package"]}"

    case "$source" in
        official)
            sudo pacman -S --needed --noconfirm "$package"
            ;;
        aur)
            aur_install "$package"
            ;;
        flatpak)
            if [[ "$FLATPAK_READY" -ne 1 ]]; then
                warn "Cannot install $package because Flatpak or Flathub is unavailable."
                return 1
            fi
            flatpak install --user -y flathub "$package"
            ;;
        *)
            warn "Unknown package source for $package."
            return 1
            ;;
    esac
}

echo
echo "Installing selected optional applications..."

for package in "${optional_packages[@]}"; do
    [[ "${SELECTED_OPTIONAL["$package"]:-0}" -eq 1 ]] || continue
    if [[ "$package" == "artcraft-launcher" ]]; then
        continue
    fi

    echo "Installing $package..."
    if install_optional_package "$package"; then
        INSTALLED_OPTIONAL["$package"]=1
    else
        warn "Could not install optional application: $package"
    fi
done

HAS_CLOUDFLARE_WARP=0
if [[ -n "${SEEN_PACKAGES["cloudflare-warp-bin"]:-}" ]] && pacman -Q cloudflare-warp-bin >/dev/null 2>&1; then
    HAS_CLOUDFLARE_WARP=1
fi

HAS_HELIUM_BROWSER=0
if [[ "${INSTALLED_OPTIONAL["helium-browser-bin"]:-0}" -eq 1 ]] &&
    pacman -Q helium-browser-bin >/dev/null 2>&1 &&
    command -v helium-browser >/dev/null 2>&1; then
    HAS_HELIUM_BROWSER=1
fi

HAS_EASYEFFECTS=0
if [[ "${INSTALLED_OPTIONAL["easyeffects"]:-0}" -eq 1 ]] &&
    pacman -Q easyeffects >/dev/null 2>&1; then
    HAS_EASYEFFECTS=1
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
    quickshell swaync waybar wlogout
    wofi xdg-desktop-portal dock-bar Thunar
)

existing_configs=()

for config in "${configs[@]}"; do
    if [[ -e "$CONFIG_DIR/$config" ]]; then
        existing_configs+=("$config")
    fi
done

[[ -f "$CONFIG_DIR/starship.toml" ]] && existing_configs+=("starship.toml")
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

if [[ -d "$REPO_DIR/Wallpapers" ]]; then
    mkdir -p "$PICTURES_DIR/Wallpapers"
    cp -ru "$REPO_DIR/Wallpapers/." "$PICTURES_DIR/Wallpapers/"
fi

# -----------------------------------------------------------------
# Set Initial Default Wallpaper with Cache
# -----------------------------------------------------------------
DEFAULT_WALLPAPER="$PICTURES_DIR/Wallpapers/18.png"
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

        # Start the daemon only if it is not responding.
        if ! awww query >/dev/null 2>&1; then
            if command -v awww-daemon &>/dev/null; then
                awww-daemon >/dev/null 2>&1 &

                for _ in {1..50}; do
                    if awww query >/dev/null 2>&1; then
                        break
                    fi
                    sleep 0.1
                done
            fi
        fi

        if awww query >/dev/null 2>&1; then
            for MONITOR in $MONITORS; do
                if awww img -o "$MONITOR" "$DEFAULT_WALLPAPER" \
                    -t random --transition-duration 1; then
                    echo "$DEFAULT_WALLPAPER" > "$CACHE_DIR/$MONITOR"
                else
                    warn "Failed to apply wallpaper to monitor: $MONITOR"
                fi
            done
        else
            warn "Awww daemon did not start; wallpaper application skipped."
        fi
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
        rm -rf "$DOCK_DIR"
        mkdir -p "$DOCK_DIR"
        cp -r "$REPO_DIR/dock-bar/." "$DOCK_DIR/"
        chmod +x "$DOCK_DIR/bin/dock-bar" 2>/dev/null || true
        mkdir -p "$HOME/.local/bin"
        ln -sf "$DOCK_DIR/bin/dock-bar" "$HOME/.local/bin/dock-bar"
        echo "  - Dock Bar installed at ~/.local/share/dock-bar"

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
# Install and Configure HyprQuickpaper Wrapper
# --------------------------------------------
echo
echo "Installing HyprQuickpaper wrapper script..."

HYPRQUICKPAPER_BIN_DIR="$HOME/.local/bin"
mkdir -p "$HYPRQUICKPAPER_BIN_DIR"

cat <<'EOF' > "$HYPRQUICKPAPER_BIN_DIR/hyprquickpaper"
#!/usr/bin/env bash
# Start HyprQuickpaper independently or send it an IPC action.

set -uo pipefail

PICKER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hyprquickpaper"
IPC_TARGET="hyprquickpaper"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprquickpaper"
LOG_FILE="$LOG_DIR/quickshell.log"
IPC_LOG="$LOG_DIR/ipc.log"
ACTION="${1:-toggle}"

usage() {
    cat <<'USAGE'
Usage: hyprquickpaper [command]

Commands:
  start    Start the independent HyprQuickpaper shell (default)
  stop     Stop the independent shell
  restart  Restart the independent shell
  toggle   Toggle the wallpaper picker
  show     Show the wallpaper picker
  hide     Hide the wallpaper picker
  log      Display the latest shell log
  help     Display this help message
USAGE
}

if ! command -v qs >/dev/null 2>&1; then
    echo "ERROR: Quickshell (qs) was not found in PATH." >&2
    exit 127
fi

if [[ ! -f "$PICKER_DIR/shell.qml" ]]; then
    echo "ERROR: HyprQuickpaper shell not found at $PICKER_DIR/shell.qml" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"

call_ipc() {
    qs -p "$PICKER_DIR" ipc call "$IPC_TARGET" "$1"
}

case "$ACTION" in
    start)
        exec qs -n -p "$PICKER_DIR" >>"$LOG_FILE" 2>&1
        ;;
    stop)
        qs kill -p "$PICKER_DIR"
        ;;
    restart)
        qs kill -p "$PICKER_DIR" >/dev/null 2>&1 || true
        exec qs -n -p "$PICKER_DIR" >>"$LOG_FILE" 2>&1
        ;;
    log)
        tail -n 100 "$LOG_FILE"
        ;;
    toggle|show|hide)
        if call_ipc "$ACTION" >"$IPC_LOG" 2>&1; then
            cat "$IPC_LOG"
            exit 0
        fi

        if [[ "$ACTION" == "hide" ]]; then
            exit 0
        fi

        qs kill -p "$PICKER_DIR" >/dev/null 2>&1 || true

        MONITOR=""
        if command -v hyprctl >/dev/null 2>&1 &&
           command -v jq >/dev/null 2>&1; then
            MONITOR="$(hyprctl monitors -j 2>/dev/null |
                jq -er '.[] | select(.focused == true) | .name' 2>/dev/null)" || MONITOR=""
        fi

        if [[ -n "$MONITOR" ]]; then
            HYPRQUICKPAPER_MONITOR="$MONITOR" qs -n -p "$PICKER_DIR" >>"$LOG_FILE" 2>&1 &
        else
            qs -n -p "$PICKER_DIR" >>"$LOG_FILE" 2>&1 &
        fi
        SHELL_PID=$!

        for _ in {1..50}; do
            if call_ipc "$ACTION" >"$IPC_LOG" 2>&1; then
                cat "$IPC_LOG"
                exit 0
            fi

            if ! kill -0 "$SHELL_PID" 2>/dev/null; then
                break
            fi

            sleep 0.1
        done

        echo "ERROR: Failed to execute IPC command $IPC_TARGET $ACTION." >&2
        echo "Configuration log: $LOG_FILE" >&2
        tail -n 40 "$LOG_FILE" >&2 || true
        cat "$IPC_LOG" >&2 2>/dev/null || true
        exit 1
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        usage
        exit 2
        ;;
esac
EOF

chmod +x "$HYPRQUICKPAPER_BIN_DIR/hyprquickpaper"
echo "  - HyprQuickpaper wrapper installed at $HYPRQUICKPAPER_BIN_DIR/hyprquickpaper"

# --------------------------------------------
# Install and Configure Settings Wrapper
# --------------------------------------------
echo
echo "Installing Settings wrapper script..."

SETTINGS_BIN_DIR="$HOME/.local/bin"
mkdir -p "$SETTINGS_BIN_DIR"

cat <<'EOF' > "$SETTINGS_BIN_DIR/settings"
#!/usr/bin/env bash
set -uo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/settings"
IPC_TARGET="settings"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/settings"
LOG_FILE="$LOG_DIR/quickshell.log"
IPC_LOG="$LOG_DIR/ipc.log"
ACTION="${1:-toggle}"

usage() {
    echo "Usage: settings [start|stop|restart|toggle|show|hide|log|sound|display|network|bluetooth|storage|power|configs]" >&2
}

if ! command -v qs >/dev/null 2>&1; then
    echo "ERROR: Quickshell (qs) was not found in PATH." >&2
    exit 127
fi

if [[ ! -f "$CONFIG/shell.qml" ]]; then
    echo "ERROR: Settings shell not found at $CONFIG/shell.qml" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"

call_ipc() {
    qs -p "$CONFIG" ipc call "$IPC_TARGET" "$1"
}

case "$ACTION" in
    start)
        exec qs -n -p "$CONFIG" >>"$LOG_FILE" 2>&1
        ;;
    stop)
        qs kill -p "$CONFIG"
        ;;
    restart)
        qs kill -p "$CONFIG" >/dev/null 2>&1 || true
        exec qs -n -p "$CONFIG" >>"$LOG_FILE" 2>&1
        ;;
    log)
        tail -n 100 "$LOG_FILE"
        ;;
    toggle|show|hide|sound|display|network|bluetooth|storage|power|configs)
        if call_ipc "$ACTION" >"$IPC_LOG" 2>&1; then
            cat "$IPC_LOG"
            exit 0
        fi

        if [[ "$ACTION" == "hide" ]]; then
            exit 0
        fi

        MONITOR=""
        if command -v hyprctl >/dev/null 2>&1 &&
           command -v jq >/dev/null 2>&1; then
            MONITOR="$(hyprctl monitors -j 2>/dev/null |
                jq -er '.[] | select(.focused == true) | .name' 2>/dev/null)" || MONITOR=""
        fi

        if [[ -n "$MONITOR" ]]; then
            QS_SETTINGS_MONITOR="$MONITOR" qs -n -p "$CONFIG" >>"$LOG_FILE" 2>&1 &
        else
            qs -n -p "$CONFIG" >>"$LOG_FILE" 2>&1 &
        fi
        SHELL_PID=$!

        for _ in {1..50}; do
            if call_ipc "$ACTION" >"$IPC_LOG" 2>&1; then
                cat "$IPC_LOG"
                exit 0
            fi

            if ! kill -0 "$SHELL_PID" 2>/dev/null; then
                break
            fi

            sleep 0.1
        done

        echo "ERROR: Failed to execute IPC command $IPC_TARGET $ACTION." >&2
        echo "Configuration log: $LOG_FILE" >&2
        tail -n 40 "$LOG_FILE" >&2 || true
        cat "$IPC_LOG" >&2 2>/dev/null || true
        exit 1
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        usage
        exit 2
        ;;
esac
EOF

chmod +x "$SETTINGS_BIN_DIR/settings"
echo "  - Settings wrapper installed at $SETTINGS_BIN_DIR/settings"

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
    APPIMAGE_URL=$(curl -fsSL "$API_URL" 2>/dev/null |
        jq -r '[.assets[]? | select(.name | endswith(".AppImage")) | .browser_download_url][0] // empty' 2>/dev/null || true)

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
# Install selected ArtCraft Launcher and import into AppManager
# --------------------------------------------
if [[ "${SELECTED_OPTIONAL["artcraft-launcher"]:-0}" -eq 1 ]]; then
    echo
    echo "Installing ArtCraft Launcher..."

    if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
        echo "Warning: curl and jq are required. Skipping ArtCraft Launcher."
    else
        case "$(uname -m)" in
            x86_64|amd64)
                ARTCRAFT_ARCH="x86_64"
                ;;
            aarch64|arm64)
                ARTCRAFT_ARCH="aarch64"
                ;;
            *)
                ARTCRAFT_ARCH=""
                echo "Warning: Unsupported architecture. Skipping ArtCraft Launcher."
                ;;
        esac

        if [[ -n "$ARTCRAFT_ARCH" ]]; then
            ARTCRAFT_API="https://api.github.com/repos/storytold/craft-launcher/releases/latest"
            ARTCRAFT_RELEASE="$(curl -fsSL --retry 2 "$ARTCRAFT_API" 2>/dev/null || true)"

            ARTCRAFT_URL="$(jq -r --arg suffix "-linux-${ARTCRAFT_ARCH}.AppImage" '
                [.assets[]? | select(.name | endswith($suffix))][0].browser_download_url // empty
            ' <<<"$ARTCRAFT_RELEASE")"

            ARTCRAFT_DIGEST="$(jq -r --arg suffix "-linux-${ARTCRAFT_ARCH}.AppImage" '
                [.assets[]? | select(.name | endswith($suffix))][0].digest // empty
            ' <<<"$ARTCRAFT_RELEASE")"

            if [[ -z "$ARTCRAFT_URL" ]]; then
                echo "Warning: Could not find the latest AppImage."
            else
                ARTCRAFT_DIR="$HOME/Applications"
                ARTCRAFT_APP="$ARTCRAFT_DIR/ArtCraft-Launcher.AppImage"
                mkdir -p "$ARTCRAFT_DIR"
                ARTCRAFT_TMP="$(mktemp "$ARTCRAFT_DIR/.artcraft.XXXXXX")"

                if curl -fL --retry 3 "$ARTCRAFT_URL" -o "$ARTCRAFT_TMP"; then
                    ARTCRAFT_VALID=1

                    if [[ "$ARTCRAFT_DIGEST" == sha256:* ]]; then
                        ARTCRAFT_EXPECTED="${ARTCRAFT_DIGEST#sha256:}"
                        ARTCRAFT_ACTUAL="$(sha256sum "$ARTCRAFT_TMP" | awk '{print $1}')"

                        if [[ "$ARTCRAFT_EXPECTED" != "$ARTCRAFT_ACTUAL" ]]; then
                            ARTCRAFT_VALID=0
                            echo "Warning: SHA-256 mismatch."
                        fi
                    fi

                    if [[ "$ARTCRAFT_VALID" -eq 1 && -s "$ARTCRAFT_TMP" ]]; then
                        chmod 755 "$ARTCRAFT_TMP"

                        if mv -f "$ARTCRAFT_TMP" "$ARTCRAFT_APP"; then
                            echo "ArtCraft Launcher downloaded: $ARTCRAFT_APP"
                            INSTALLED_OPTIONAL["artcraft-launcher"]=1

                            if command -v app-manager &>/dev/null; then
                                app-manager install "$ARTCRAFT_APP" \
                                    || echo "Warning: AppManager import failed; AppImage is available manually."
                            else
                                echo "AppManager CLI not found; AppImage was saved without importing."
                            fi
                        fi
                    fi
                else
                    echo "Warning: ArtCraft Launcher download failed."
                fi

                rm -f "$ARTCRAFT_TMP"
            fi
        fi
    fi
else
    echo
    echo "Skipping ArtCraft Launcher (not selected)."
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
} >"$MONITORS_LUA_CONFIG"

if [[ -f "$KEYBINDS_LUA_CONFIG" ]] && [[ ${#monitor_entries[@]} -le 1 ]]; then
    perl -0777 -pi -e 's/\n    -- ============================================================\n    -- MOVE WINDOW BETWEEN WORKSPACES \(6 = HDMI\)\n    -- ============================================================\n\n   hl.bind\(mainMod \.\. " \+ R", function\(\).*?end\)\n\n//s' "$KEYBINDS_LUA_CONFIG"
fi

if [[ ${#monitor_entries[@]} -gt 0 ]]; then
    echo "  Generated $MONITORS_LUA_CONFIG with ${#monitor_entries[@]} monitor(s)"
else
    echo "  Generated $MONITORS_LUA_CONFIG with generic fallback"
fi

# --------------------------------------------
# Configure vm.max_map_count for games
# --------------------------------------------
echo
echo "Configuring vm.max_map_count for heavy games..."

SYSCTL_CONF="/etc/sysctl.d/99-max_map_count.conf"
SYSCTL_KEY="vm.max_map_count"
SYSCTL_VALUE="1048576"
SYSCTL_TMP="$(mktemp)"

# Preserve other settings and remove previous active assignments
# to vm.max_map_count from the managed file.
if [[ -f "$SYSCTL_CONF" ]]; then
    if ! awk \
        '!/^[[:space:]]*vm[.]max_map_count[[:space:]]*=/' \
        "$SYSCTL_CONF" > "$SYSCTL_TMP"; then
        rm -f "$SYSCTL_TMP"
        warn "Could not read $SYSCTL_CONF; skipping vm.max_map_count setup."
        SYSCTL_TMP=""
    fi
else
    : > "$SYSCTL_TMP"
fi

if [[ -n "$SYSCTL_TMP" ]]; then
    printf '%s = %s\n' "$SYSCTL_KEY" "$SYSCTL_VALUE" \
        >> "$SYSCTL_TMP"

    if sudo install -D -o root -g root -m 0644 \
        "$SYSCTL_TMP" "$SYSCTL_CONF"; then

        rm -f "$SYSCTL_TMP"
        SYSCTL_TMP=""

        # Apply the system sysctl configuration.
        if sudo sysctl --system; then
            CURRENT_VALUE="$(sysctl -n "$SYSCTL_KEY" 2>/dev/null || true)"

            if [[ "$CURRENT_VALUE" == "$SYSCTL_VALUE" ]]; then
                echo "  - $SYSCTL_KEY is set to $SYSCTL_VALUE (persistent and active)."
            else
                warn "$SYSCTL_CONF was updated, but the effective value is '$CURRENT_VALUE' instead of '$SYSCTL_VALUE'. Another sysctl configuration may be overriding it."
            fi
        else
            warn "sysctl --system failed; attempting to apply $SYSCTL_KEY directly."

            if sudo sysctl -w "$SYSCTL_KEY=$SYSCTL_VALUE"; then
                echo "  - $SYSCTL_KEY applied to the current session."
                echo "  - The persistent configuration is saved in $SYSCTL_CONF."
            else
                warn "Could not apply $SYSCTL_KEY. Check the system logs."
            fi
        fi
    else
        rm -f "$SYSCTL_TMP"
        SYSCTL_TMP=""
        warn "Could not write $SYSCTL_CONF."
    fi
fi

[[ -z "$SYSCTL_TMP" ]] || rm -f "$SYSCTL_TMP"

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
            ' "$WAYBAR_CONFIG" >"$WAYBAR_TMP"; then
                if jq -e 'if type == "array" then any(.[]; type == "object" and has("output")) elif type == "object" then has("output") else false end' "$WAYBAR_CONFIG" >/dev/null; then
                    cat "$WAYBAR_TMP" >"$WAYBAR_CONFIG"
                    echo "  - Updated Waybar output to detected monitor: $first_monitor."
                else
                    warn "Waybar config has no output field; leaving it unchanged."
                fi
            else
                warn "Could not update Waybar JSON; original file was preserved."
            fi
        else
            if jq 'if type == "array" then map(if type == "object" then del(.output) else . end) elif type == "object" then del(.output) else . end' "$WAYBAR_CONFIG" >"$WAYBAR_TMP"; then
                cat "$WAYBAR_TMP" >"$WAYBAR_CONFIG"
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

if [[ "$HAS_EASYEFFECTS" -eq 1 ]] &&
    pacman -Q easyeffects >/dev/null 2>&1 &&
    [[ -x /usr/bin/easyeffects ]]; then
    SYSTEMD_USER_DIR="$CONFIG_DIR/systemd/user"
    EASYEFFECTS_SERVICE="$SYSTEMD_USER_DIR/easyeffects.service"

    mkdir -p "$SYSTEMD_USER_DIR"

    cat >"$EASYEFFECTS_SERVICE" <<'EOF'
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
    echo "  - EasyEffects was not selected or installed; skipping its user service."
fi

# --------------------------------------------
# Configure SwayNC systemd user service
# --------------------------------------------
echo
echo "Configuring SwayNC user service..."

SYSTEMD_USER_DIR="$CONFIG_DIR/systemd/user"
SWAYNC_SERVICE="$SYSTEMD_USER_DIR/swaync.service"

mkdir -p "$SYSTEMD_USER_DIR"

cat >"$SWAYNC_SERVICE" <<'EOF'
[Unit]
Description=SwayNotificationCenter
PartOf=graphical-session.target
After=graphical-session.target

[Service]
ExecStart=/usr/bin/swaync
Environment=GDK_WAYLAND_DISABLE=ext_background_effect_manager_v1
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF

echo "  - Created SwayNC service file"

if [[ -f "$CONFIG_DIR/hypr/autostart.lua" ]]; then
    sed -i '/hl\.exec_cmd("swaync")/d' "$CONFIG_DIR/hypr/autostart.lua"
    echo "  - Removed swaync from autostart.lua (now managed by systemd)"
fi

if command -v systemctl &>/dev/null; then
    if systemctl --user daemon-reload 2>/dev/null && systemctl --user enable --now swaync.service 2>/dev/null; then
        echo "  - SwayNC user service enabled."
    else
        echo "  - Warning: could not enable the SwayNC user service in this session."
    fi
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
        echo "Exec=$exec_cmd" >>"$local_file"
    fi

    if grep -q "^Terminal=" "$local_file"; then
        sed -i "s|^Terminal=.*|Terminal=false|" "$local_file"
    else
        echo "Terminal=false" >>"$local_file"
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
# Helium DRM Fixer Automation
# --------------------------------------------
if [[ "$HAS_HELIUM_BROWSER" -eq 1 ]]; then
    echo
    echo "Starting Helium DRM Fixer setup..."

    sudo pacman -S --needed --noconfirm bun

    HELIUM_DRM_DIR="/tmp/helium-drm-fixer"
    HELIUM_PROFILE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/net.imput.helium"
    HELIUM_BOOTSTRAP_LOG="${TMPDIR:-/tmp}/helium-drm-bootstrap-$$.log"
    HELIUM_BOOTSTRAP_PID=""
    CHROME_WAS_INSTALLED=0
    CHROME_INSTALLED_BY_SCRIPT=0

    if pacman -Qi google-chrome &>/dev/null; then
        CHROME_WAS_INSTALLED=1
    fi

    helium_profile_files_ready() {
        [[ -s "$HELIUM_PROFILE_DIR/Local State" &&
            -s "$HELIUM_PROFILE_DIR/Default/Preferences" ]]
    }

    collect_helium_bootstrap_tree() {
        local parent_pid="$1"
        local child_pid

        while IFS= read -r child_pid; do
            [[ -n "$child_pid" ]] || continue
            HELIUM_BOOTSTRAP_TREE+=("$child_pid")
            collect_helium_bootstrap_tree "$child_pid"
        done < <(pgrep -P "$parent_pid" 2>/dev/null || true)
    }

    stop_helium_bootstrap() {
        [[ -n "$HELIUM_BOOTSTRAP_PID" ]] || return 0

        if kill -0 "$HELIUM_BOOTSTRAP_PID" 2>/dev/null; then
            local -a HELIUM_BOOTSTRAP_TREE=()
            local -a HELIUM_BOOTSTRAP_TARGETS=()
            local pid
            local running

            collect_helium_bootstrap_tree "$HELIUM_BOOTSTRAP_PID"
            HELIUM_BOOTSTRAP_TARGETS=(
                "${HELIUM_BOOTSTRAP_TREE[@]}"
                "$HELIUM_BOOTSTRAP_PID"
            )

            kill -TERM "${HELIUM_BOOTSTRAP_TARGETS[@]}" 2>/dev/null || true

            for _ in {1..10}; do
                running=0

                for pid in "${HELIUM_BOOTSTRAP_TARGETS[@]}"; do
                    if kill -0 "$pid" 2>/dev/null; then
                        running=1
                        break
                    fi
                done

                [[ "$running" -eq 1 ]] || break
                sleep 1
            done

            for pid in "${HELIUM_BOOTSTRAP_TARGETS[@]}"; do
                kill -KILL "$pid" 2>/dev/null || true
            done
        fi

        wait "$HELIUM_BOOTSTRAP_PID" 2>/dev/null || true
        HELIUM_BOOTSTRAP_PID=""
    }

    prepare_helium_profile() {
        local HELIUM_LAUNCHER
        local PROFILE_READY=0

        if helium_profile_files_ready; then
            echo "  - Helium profile files already exist."
            return 0
        fi

        if [[ -L "$HELIUM_PROFILE_DIR/SingletonLock" ||
              -e "$HELIUM_PROFILE_DIR/SingletonLock" ||
              -L "$HELIUM_PROFILE_DIR/SingletonSocket" ||
              -e "$HELIUM_PROFILE_DIR/SingletonSocket" ]]; then

            echo "  - Helium profile appears to be in use."
            echo "  - Waiting for the profile files without launching another instance..."

            for _ in {1..30}; do
                if helium_profile_files_ready; then
                    echo "  - Helium profile files verified."
                    return 0
                fi

                sleep 1
            done

            warn "Helium profile is in use, but the required files are missing."
            return 1
        fi

        HELIUM_LAUNCHER="$(command -v helium-browser || true)"

        if [[ -z "$HELIUM_LAUNCHER" ]]; then
            warn "Helium launcher was not found."
            return 1
        fi

        mkdir -p "$HELIUM_PROFILE_DIR" || {
            warn "Could not create the Helium profile directory."
            return 1
        }

        : > "$HELIUM_BOOTSTRAP_LOG"

        echo "  - Starting Helium in the background..."
        echo "  - Waiting for profile files..."
        echo "  - Log: $HELIUM_BOOTSTRAP_LOG"

        "$HELIUM_LAUNCHER" \
            --headless \
            --disable-gpu \
            --no-first-run \
            --no-default-browser-check \
            --user-data-dir="$HELIUM_PROFILE_DIR" \
            about:blank \
            > >(tee -a "$HELIUM_BOOTSTRAP_LOG") 2>&1 &

        HELIUM_BOOTSTRAP_PID=$!

        for _ in {1..30}; do
            if helium_profile_files_ready; then
                PROFILE_READY=1
                break
            fi

            if ! kill -0 "$HELIUM_BOOTSTRAP_PID" 2>/dev/null; then
                break
            fi

            sleep 1
        done

        stop_helium_bootstrap

        if [[ "$PROFILE_READY" -eq 1 ]]; then
            echo "  - Helium profile files verified."
            return 0
        fi

        warn "Helium did not create the required profile files."
        warn "Check the bootstrap log: $HELIUM_BOOTSTRAP_LOG"
        return 1
    }

    cleanup_helium_drm() {
        stop_helium_bootstrap
        rm -rf -- "$HELIUM_DRM_DIR"

        if [[ "$CHROME_INSTALLED_BY_SCRIPT" -eq 1 ]]; then
            sudo pacman -Rns --noconfirm google-chrome &>/dev/null || true

            if [[ "$AUR_HELPER" == "yay" ]]; then
                rm -rf -- "$HOME/.cache/yay/google-chrome"
            elif [[ "$AUR_HELPER" == "paru" ]]; then
                rm -rf -- "$HOME/.cache/paru/clone/google-chrome"
            fi
        fi
    }

    trap cleanup_helium_drm EXIT

    rm -rf -- "$HELIUM_DRM_DIR"

    if git clone https://github.com/PHNexus/helium-drm-fixer.git "$HELIUM_DRM_DIR"; then
        if [[ "$CHROME_WAS_INSTALLED" -eq 0 ]]; then
            echo "Installing Google Chrome temporarily via $AUR_HELPER..."

            if printf 'Y\n' | aur_install google-chrome; then
                CHROME_INSTALLED_BY_SCRIPT=1
            else
                warn "Could not install temporary Google Chrome."
            fi
        else
            echo "  - Existing Google Chrome installation detected."
        fi

        if pacman -Qi google-chrome &>/dev/null; then
            if prepare_helium_profile; then
                if (
                    cd "$HELIUM_DRM_DIR" &&
                    bun install &&
                    bun run cli.ts
                ); then
                    echo "  - Helium DRM Fixer completed."
                else
                    warn "Helium DRM Fixer failed; continuing."
                fi
            else
                warn "Helium profile initialization failed; skipping the DRM fixer."
            fi
        else
            warn "Google Chrome is unavailable; skipping the DRM fixer."
        fi
    else
        warn "Could not clone Helium DRM Fixer; skipping this optional step."
    fi

    cleanup_helium_drm
    trap - EXIT

    echo "Helium DRM Fixer step finished."

    # --------------------------------------------
    # Configure Helium Browser Flags
    # --------------------------------------------
    echo
    echo "Configuring Helium browser flags..."

    mkdir -p "$CONFIG_DIR"

    cat >"$CONFIG_DIR/helium-browser-flags.conf" <<'EOF'
--enable-features=VaapiVideoDecoder,AcceleratedVideoDecodeLinuxGL,VaapiVideoEncoder
--ignore-gpu-blocklist
--enable-zero-copy
--ozone-platform=wayland
--enable-gpu-rasterization
--use-gl=angle
--use-angle=gl
EOF

    echo "  - Created helium-browser-flags.conf successfully."

    # --------------------------------------------
    # Configure Helium Cookie Exceptions via Policy
    # --------------------------------------------
    echo
    echo "Configuring Helium cookie exceptions..."

    sudo mkdir -p /etc/chromium/policies/managed

    sudo tee /etc/chromium/policies/managed/cookie_exceptions.json >/dev/null <<'EOF'
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
    echo "Skipping Helium browser configuration: helium-browser-bin was not selected or installed."
fi

# --------------------------------------------
# Install and Configure GameMode
# --------------------------------------------
echo
echo "Installing and configuring GameMode..."

sudo pacman -S --needed --noconfirm gamemode lib32-gamemode

if command -v gamemoded >/dev/null 2>&1; then
    if gamemoded -t; then
        echo "  - GameMode diagnostic test passed."
    else
        warn "GameMode diagnostic test failed; inspect the output above before relying on it."
    fi
else
    warn "gamemoded was not found after package installation."
fi

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
    CPUPOWER_CONF=""
    for candidate in /etc/default/cpupower /etc/default/cpupower-service.conf; do
        if [[ -f "$candidate" ]]; then
            CPUPOWER_CONF="$candidate"
            break
        fi
    done
    if [[ -n "$CPUPOWER_CONF" ]]; then
        sudo sed -i '/^GOVERNOR=/d' "$CPUPOWER_CONF"
        echo 'GOVERNOR="performance"' | sudo tee -a "$CPUPOWER_CONF" >/dev/null
        if sudo systemctl enable --now cpupower.service; then
            echo "  - cpupower service enabled with 'performance' governor."
        else
            warn "Could not enable cpupower.service; the configuration file was updated."
        fi
    else
        echo "  - cpupower config not found, skipping."
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

    if command -v systemctl &>/dev/null; then
        if sudo systemctl enable --now warp-svc; then
            echo "  - warp-svc service enabled and started."
        else
            warn "Could not enable warp-svc; WARP CLI configuration may not work."
        fi

        sleep 3
    fi

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

    if command -v systemctl &>/dev/null; then
        sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
    fi

    if command -v nmcli &>/dev/null; then
        ACTIVE_CONN=$(nmcli -t -f NAME,DEVICE connection show --active | grep -v ':lo$' | head -n1 | cut -d: -f1 || true)

        if [[ -n "$ACTIVE_CONN" ]]; then
            if sudo nmcli connection modify "$ACTIVE_CONN" ipv4.dns "1.1.1.1,1.0.0.1" &&
                sudo nmcli connection modify "$ACTIVE_CONN" ipv4.ignore-auto-dns yes &&
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
        echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
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