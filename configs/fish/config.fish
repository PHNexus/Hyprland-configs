# ============================================================
# Shell greeting
# ============================================================
set -g fish_greeting

# ============================================================
# Starship prompt
# ============================================================
starship init fish | source

# ============================================================
# PATH
# ============================================================
fish_add_path ~/.local/bin
fish_add_path /opt/cuda/bin
fish_add_path /home/mark/.spicetify
fish_add_path ~/.local/share/npm-global/bin

# ============================================================
# Environment variables
# ============================================================
set -gx __GL_YIELD USLEEP
set -gx __GL_THREADED_OPTIMIZATIONS 1
set -gx CUDACXX /opt/cuda/bin/nvcc
set -gx EDITOR nvim
set -gx VISUAL nvim

# ============================================================
# Aliases
# ============================================================
alias minecraft "sklauncher; pkill -f sklauncher"
alias update "bash ~/Documents/GitHub/Hyprland-configs/update-dotfiles.sh"
alias freeram "sync && sudo sysctl vm.drop_caches=3"
alias xdg-open-appstream "gio open"

# ============================================================
# Abbreviations
# ============================================================
abbr --add ai ~/bin/ai
abbr --add ia 'helium-browser http://localhost:8080'

# ============================================================
# Fastfetch (only interactive, LAST thing)
# ============================================================
function fastfetch-nofail
    stty -echo
    fastfetch
    stty echo
    commandline -f repaint
end

if status is-interactive
    fastfetch-nofail
end