#!/usr/bin/env bash
set -eu

WALL="$1"
CACHE_DIR="$HOME/.cache/wallpapers_state"
mkdir -p "$CACHE_DIR"

MONITORS=$(hyprctl monitors -j | jq -r '.[].name')
MONITOR_COUNT=$(echo "$MONITORS" | wc -l)

if [ "$MONITOR_COUNT" -eq 1 ]; then
    awww img -o "$MONITORS" "$WALL" -t random --transition-duration 1
    echo "$WALL" > "$CACHE_DIR/$MONITORS"
else
    CHOSEN_MONITOR=$(echo -e "All\n$MONITORS" | wofi --dmenu --prompt "Select your monitor")

    [ -z "$CHOSEN_MONITOR" ] && exit 0

    if [ "$CHOSEN_MONITOR" = "All" ]; then
        for MONITOR in $MONITORS; do
            awww img -o "$MONITOR" "$WALL" -t random --transition-duration 1
            echo "$WALL" > "$CACHE_DIR/$MONITOR"
        done
    else
        awww img -o "$CHOSEN_MONITOR" "$WALL" -t random --transition-duration 1
        echo "$WALL" > "$CACHE_DIR/$CHOSEN_MONITOR"
    fi
fi