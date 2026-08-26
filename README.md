
## Hyprland Rice
Welcome to my Hyprland Rice configuration! This setup is designed to provide a clean, efficient, and visually appealing desktop environment.
I use these configs daily 

## Screenshots
| <img width="1925" height="1081" alt="2026-08-23-135156_hyprshot" src="https://github.com/user-attachments/assets/32116be3-b4c3-48b1-829e-6207a02023b6" /> | <img width="1925" height="1081" alt="2026-08-26-155806_hyprshot" src="https://github.com/user-attachments/assets/df31a3c9-e323-463f-aa51-d821ab54b5c8" />|
|---|---|
|<img width="1918" height="1080" alt="2026-08-26-155820_hyprshot" src="https://github.com/user-attachments/assets/27bb891c-e59f-407c-98ac-808eaf6fe5b5" /> | <img width="1920" height="1080" alt="2026-08-23-142231_hyprshot" src="https://github.com/user-attachments/assets/da4b0ac9-2d28-4ca3-9746-3ae4d7bbfae4" /> 




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


## Keybinds

Modifier key (`$mainMod`) is **SUPER** (Windows key).

### Apps & Scripts

| Keybind | Action |
|---|---|
| `SUPER + T` | Open terminal (kitty) |
| `SUPER + Space` | App launcher (wofi) |
| `SUPER + E` | File manager (thunar) |
| `SUPER + C` | Open VS Code (code) |
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
| `SUPER + ← / → / ↑ / ↓` | Move focus |
| `SUPER + LMB drag` | Move window |
| `SUPER + RMB drag` | Resize window |

### Workspaces

| Keybind | Action |
|---|---|
| `SUPER + [1-4]` | Switch to workspace |
| `SUPER + SHIFT + [1-4]` | Move window to workspace |
| `SUPER + Tab` | Previous workspace |
| `SUPER + ALT + ← / →` | Cycle workspaces |
| `SUPER + SHIFT + ← / →` | Move window to adjacent workspace |
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
