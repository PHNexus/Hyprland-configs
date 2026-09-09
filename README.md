
## Hyprland Rice
Welcome to my Hyprland Rice configuration! This setup is designed to provide a clean, efficient, and visually appealing desktop environment.
I use these configs daily 

#### Scrolling mode | looks like Niri  


## Screenshots
|<img width="1939" height="1080" alt="2026-09-09-095142_hyprshot" src="https://github.com/user-attachments/assets/260686ef-4b25-4b41-8a6d-23bc4557e12b" /> | <img width="1930" height="1081" alt="2026-09-09-095748_hyprshot" src="https://github.com/user-attachments/assets/b5f2844d-ad29-4245-a8b3-3157e09bf1c7" /> |
|---|---|
| <img width="1921" height="1081" alt="2026-09-09-094547_hyprshot" src="https://github.com/user-attachments/assets/92f08967-f092-45db-929f-5129a1345ee6" />  | <img width="1920" height="1080" alt="print_hyprlock" src="https://github.com/user-attachments/assets/0bb1dacf-c88e-4139-a640-a3df4abe5eb2" />


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
| Browser | [Zen](https://zen-browser.app/) |
| Display Manager (Default) | [Ly](https://codeberg.org/fairyglade/ly#systemd) |


## Installation

Clone the repository and run the installation script to automatically set up the dependencies and configuration files:                                          
#### You'll have to edit some things like monitors config

```bash
git clone https://github.com/PHNexus/Hyprland-configs.git
cd Hyprland-configs
chmod +x install.sh
./install.sh
```

## [Dependencies](packages.txt)


# Keybinds

Modifier key (`$mainMod`) is **SUPER** (Windows key).
## Apps & Scripts

| Keybind | Action |
|---|---|
| `SUPER + T` | Open terminal (`kitty`) |
| `SUPER + Space` | App launcher (`wofi`) |
| `SUPER + E` | File manager (`thunar`) |
| `SUPER + C` | Open VS Code (`code`) |
| `SUPER + B` | Open browser (`zen-browser`) |
| `SUPER + V` | Clipboard history (`cliphist`) |
| `SUPER + L` | Lock screen (`hyprlock`) |
| `SUPER + SHIFT + R` | Set random wallpaper script |
| `SUPER + W` | Wallpaper picker |

## Window Management

| Keybind | Action |
|---|---|
| `SUPER + Q` | Close active window |
| `SUPER + SHIFT + W` | Toggle Waybar |
| `SUPER + S` | Toggle floating + center + resize 1000x600 |
| `SUPER + M` | Exit Hyprland |
| `SUPER + D` | Move column (`move +col`) |
| `SUPER + A` | Move column (`move -col`) |
| `SUPER + R` | Toggle window between primary monitor (workspace 1) and secondary monitor (workspace 6) |
| `SUPER + equal` | Resize column (`colresize +conf`) |
| `SUPER + minus` | Resize column (`colresize -conf`) |
| `SUPER + f` | Resize column (`colresize +conf`) |
| `SUPER + l / j / i / k` | Move focus (left, right, up, down) |
| `SUPER + left / right` | Consume or expel window (`consume_or_expel`) |
| `SUPER + SHIFT + left / right` | Move window to adjacent direction |
| `SUPER + mouse:272` | Drag / move floating window |
| `SUPER + mouse:273` | Resize floating window |

## Workspaces

| Keybind | Action |
|---|---|
| `SUPER + [1-4]` | Switch to workspace 1–4 |
| `SUPER + SHIFT + [1-4]` | Move window to workspace 1–4 |
| `SUPER + Tab` | Switch to previous workspace |
| `ALT + Tab` | Cycle to next window and bring to top |
| `ALT + SHIFT + Tab` | Cycle to previous workspace and bring to top |
| `SUPER + ALT + left / right` | Cycle workspaces (`m-1` / `m+1`) |
| `SUPER + mouse_down` | Scroll to next workspace (`e+1`) |
| `SUPER + mouse_up` | Scroll to previous workspace (`e-1`) |

## Media & Brightness

| Keybind | Action |
|---|---|
| `XF86AudioRaiseVolume` | Volume up (`wpctl 5%+`) |
| `XF86AudioLowerVolume` | Volume down (`wpctl 5%-`) |
| `XF86AudioMute` | Toggle audio sink mute |
| `XF86AudioMicMute` | Toggle microphone source mute |
| `XF86MonBrightnessUp` | Brightness up (`brightnessctl 5%+`) |
| `XF86MonBrightnessDown` | Brightness down (`brightnessctl 5%-`) |

## Screenshots

| Keybind | Action |
|---|---|
| `SUPER + SHIFT + S` | Screenshot region via `hyprshot` → `~/Pictures/Screenshots` |
