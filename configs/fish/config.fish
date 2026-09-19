set -g fish_greeting

starship init fish | source

# Fastfetch (só em terminal interativo)
if status is-interactive
    fastfetch
end

# ============================================================
# PATH
# ============================================================
fish_add_path ~/.local/bin
fish_add_path /opt/cuda/bin

# ============================================================
# Variáveis de ambiente
# ============================================================
set -gx __GL_YIELD USLEEP
set -gx __GL_THREADED_OPTIMIZATIONS 1

# CUDA
set -gx CUDACXX /opt/cuda/bin/nvcc

# ============================================================
# Aliases
# ============================================================
alias minecraft "sklauncher; pkill -f sklauncher"
alias sync-dotfiles "bash ~/Documents/GitHub/Hyprland-configs/sync-dotfiles.sh"
alias freeram "sync && sudo sysctl vm.drop_caches=3"
alias xdg-open-appstream "gio open"

# ============================================================
# IA local
# ============================================================
abbr --add ai ~/bin/ai
abbr --add ia 'helium-browser http://localhost:8080'

set -gx EDITOR nvim
set -gx VISUAL nvim
