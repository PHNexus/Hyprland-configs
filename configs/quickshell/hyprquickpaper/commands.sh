#!/usr/bin/env bash
set -eu

WALL="$1"

# 1. Obter a lista de monitores conectados via hyprctl
MONITORS=$(hyprctl monitors -j | jq -r '.[].name')

# 2. Pergunta via Wofi em qual monitor deve ser aplicado
CHOSEN_MONITOR=$(echo -e "Todos\n$MONITORS" | wofi --dmenu --prompt "Selecione o monitor")

# Se cancelar o menu do Wofi, interrompe a alteração
[ -z "$CHOSEN_MONITOR" ] && exit 0

# 3. Executa o awww com base na escolha
if [ "$CHOSEN_MONITOR" = "Todos" ]; then
    awww img "$WALL" -t random --transition-duration 1[cite: 24]
else
    awww img -o "$CHOSEN_MONITOR" "$WALL" -t random --transition-duration 1
fi