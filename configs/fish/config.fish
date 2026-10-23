# ============================================================
# Shell greeting
# ============================================================
set -g fish_greeting ""

# ============================================================
# Prompt (Starship)
# ============================================================
if command -v starship &> /dev/null
    starship init fish | source
end

# ============================================================
# PATH
# ============================================================
fish_add_path ~/.local/bin
fish_add_path ~/.cargo/bin
fish_add_path ~/go/bin
fish_add_path /opt/cuda/bin
fish_add_path ~/.spicetify
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

# eza replaces ls if available
if command -v eza &> /dev/null
    alias ls 'eza --icons --group-directories-first'
    alias ll 'eza --icons --group-directories-first -l'
    alias la 'eza --icons --group-directories-first -a'
    alias lla 'eza --icons --group-directories-first -la'
    alias lt 'eza --icons --group-directories-first --tree --level=2'
end

# bat replaces cat if available
if command -v bat &> /dev/null
    alias cat 'bat --paging=never'
end

# ============================================================
# Abbreviations — general
# ============================================================
abbr --add ai ~/bin/ai
abbr --add ia 'helium-browser http://localhost:8080'

# Common commands
abbr c 'clear'
abbr h 'history'
abbr pacsize 'expac -H M "%m\t%n" $(pacman -Qeq) | sort -h -r'
abbr pacsizefull 'expac -H M "%m\t%n" | sort -h -r'

# ============================================================
# Abbreviations — git
# ============================================================
abbr lg 'lazygit'
abbr gd 'git diff'
abbr ga 'git add .'
abbr gc 'git commit -am'
abbr gl 'git log'
abbr gs 'git status'
abbr gst 'git stash'
abbr gsp 'git stash pop'
abbr gp 'git push'
abbr gpl 'git pull'
abbr gsw 'git switch'
abbr gsm 'git switch main'
abbr gb 'git branch'
abbr gbd 'git branch -d'
abbr gco 'git checkout'
abbr gsh 'git show'

# ============================================================
# Abbreviations — listings (fall back to ls flags)
# ============================================================
abbr l 'ls'
abbr ll 'ls -l'
abbr la 'ls -a'
abbr lla 'ls -la'

# ============================================================
# Fastfetch (interactive only, last thing)
# ============================================================
if status is-interactive && command -v fastfetch &> /dev/null
    function fastfetch-nofail --description "Run fastfetch without disturbing the prompt"
        stty -echo
        fastfetch
        stty echo
        commandline -f repaint
    end
    fastfetch-nofail
end