#!/usr/bin/env bash
set -eu

WALL="$1"

MONITORS=$(hyprctl monitors -j | jq -r '.[].name')

CHOSEN_MONITOR=$(echo -e "Todos\n$MONITORS" | wofi --dmenu --prompt "Selecione o monitor")

[ -z "$CHOSEN_MONITOR" ] && exit 0

if [ "$CHOSEN_MONITOR" = "Todos" ]; then
    for MONITOR in $MONITORS; do
        awww img -o "$MONITOR" "$WALL" -t random --transition-duration 1
    done
else
    awww img -o "$CHOSEN_MONITOR" "$WALL" -t random --transition-duration 1
fi