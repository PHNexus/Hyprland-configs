# Desativa a mensagem de boas-vindas padrão do Fish
set -g fish_greeting

#fastfetch 
if status is-interactive
    fastfetch
end

# Aliases 
alias minecraft "sklauncher; pkill -f sklauncher"
alias sync-dotfiles="bash ~/Documents/GitHub/Hyprland-configs/sync-dotfiles.sh"
alias freeram "sync && sudo sysctl vm.drop_caches=3"
alias xdg-open-appstream="gio open"
set -gx PATH $HOME/.local/bin $PATH
