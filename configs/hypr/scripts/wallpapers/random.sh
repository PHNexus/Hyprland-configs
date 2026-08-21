#!/bin/bash
set -eu

WALLPAPERS_DIR="$HOME/Pictures/Wallpapers"
HISTORY_FILE="$HOME/.cache/wallpaper_history.txt"

mkdir -p "$(dirname "$HISTORY_FILE")"
touch "$HISTORY_FILE"

FILE_LIST=$(find "$WALLPAPERS_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) -printf "%f\n" | sort)
AVAILABLE_LIST=$(comm -23 <(echo "$FILE_LIST") <(sort "$HISTORY_FILE"))

if [ -z "$AVAILABLE_LIST" ]; then
    > "$HISTORY_FILE"
    AVAILABLE_LIST="$FILE_LIST"
fi

SELECTED_FILE=$(echo "$AVAILABLE_LIST" | shuf -n 1)

echo "$SELECTED_FILE" >> "$HISTORY_FILE"

echo "$WALLPAPERS_DIR/$SELECTED_FILE"