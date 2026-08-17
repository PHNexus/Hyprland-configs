#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
alias minecraft="sklauncher; pkill -f sklauncher"
alias minecraft="sklauncher; pkill -f sklauncher"

export PATH=$PATH:/home/mark/.spicetify

# Hermes Agent — ensure ~/.local/bin is on PATH
export PATH="$HOME/.local/bin:$PATH"
