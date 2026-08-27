
## Hyprland Rice
Welcome to my Hyprland Rice configuration! This setup is designed to provide a clean, efficient, and visually appealing desktop environment.
I use these configs daily 

## Screenshots
|<img width="1923" height="1081" alt="2026-08-26-160349_hyprshot" src="https://github.com/user-attachments/assets/c0dd9a64-1091-4d79-955d-e26a99139a7c" />| <img width="1922" height="1081" alt="2026-08-27-192953_hyprshot" src="https://github.com/user-attachments/assets/a3858eb4-66c7-4c66-9007-5b8018b70ce0" />|
|---|---|
| <img width="1925" height="1080" alt="2026-08-27-193007_hyprshot" src="https://github.com/user-attachments/assets/3cc43026-5fd4-483a-b02d-370b17e490ff" /><img width="1920" height="1080" alt="hyprlock_screenshot" src="https://github.com/user-attachments/assets/e8fb7175-7bde-407e-b4b1-6f2a7a824320" /> 

| Component | Program |
|---|---|
| Terminal | [Kitty](https://github.com/kovidgoyal/kitty) |
| App Launcher | [Wofi](https://hg.sr.ht/~scoopta/wofi) |
| Status Bar | [Waybar](https://github.com/alexays/waybar) |
| Shell | [Fish](https://fishshell.com/) + [Starship](https://starship.rs/) |
| File Manager | [Thunar](https://docs.xfce.org/xfce/thunar/start) |
| Notifications & Control Center | [SwayNC](https://github.com/ErikReider/SwayNotificationCenter) |
| Wallpaper | [Awww](https://codeberg.org/LGFae/awww) |
| Idle Management | [Hypridle](https://github.com/hyprwm/hypridle) |
| Screen Lock | [Hyprlock](https://github.com/hyprwm/hyprlock) |
| Editor | [VS Code](https://code.visualstudio.com/) + [Neovim](https://neovim.io/)|
| Browser | [Helium](https://helium.computer/) |
| Display Manager (Default) | [Ly](https://codeberg.org/fairyglade/ly#systemd) |


## [Dependencies](packages.txt)


# Keybinds

Modifier key (`$mainMod`) is **SUPER** (Windows key).

### Apps & Scripts

| Keybind | Action |
|---|---|
| `SUPER + T` | Open terminal (kitty) |
| `SUPER + Space` | App launcher (wofi) |
| `SUPER + E` | File manager (thunar) |
| `SUPER + C` | Open VS Code (code) |
| `SUPER + B` | Open browser (helium-browser) |
| `SUPER + V` | Clipboard history (cliphist) |
| `SUPER + L` | Lock screen (hyprlock) |
| `SUPER + SHIFT + R` | Set random wallpaper |
| `SUPER + W` | Wallpaper picker |
| `SUPER + SHIFT + code:201` | Open Claude in Firefox |

### Window Management

| Keybind | Action |
|---|---|
| `SUPER + Q` | Close active window |
| `SUPER + SHIFT + W` | Toggle Waybar |
| `SUPER + F` | Toggle floating + center + resize 1000x600 |
| `SUPER + M` | Exit Hyprland |
| `SUPER + D` | Move column (move +col) |
| `SUPER + A` | Move column (move -col) |
| `SUPER + R` | Move window to second monitor  |
| `SUPER + equal` | Resize column (+conf) |
| `SUPER + minus` | Resize column (-conf) |
| `SUPER + l / j / i / k` | Move focus |
| `SUPER + left / right` | Consume or expel window |
| `SUPER + mouse:272` | Move window |
| `SUPER + mouse:273` | Resize window |

### Workspaces

| Keybind | Action |
|---|---|
| `SUPER + [1-4]` | Switch to workspace |
| `SUPER + SHIFT + [1-4]` | Move window to workspace |
| `SUPER + Tab` | Previous workspace |
| `SUPER + ALT + left / right` | Cycle workspaces |
| `SUPER + SHIFT + left / right` | Move window to adjacent workspace |
| `SUPER + mouse_down` | Scroll to next workspace |
| `SUPER + mouse_up` | Scroll to previous workspace |

### Media & Brightness

| Keybind | Action |
|---|---|
| `XF86AudioRaiseVolume` | Volume up (wpctl +5%) |
| `XF86AudioLowerVolume` | Volume down (wpctl -5%) |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioMicMute` | Toggle mic mute |
| `XF86MonBrightnessUp` | Brightness up (brightnessctl +5%) |
| `XF86MonBrightnessDown` | Brightness down (brightnessctl -5%) |

### Screenshots

| Keybind | Action |
|---|---|
| `SUPER + SHIFT + S` | Screenshot region → `~/Pictures/Screenshots` |
