#!/bin/bash
set -eu

WALLPAPERS_DIR="$HOME/Pictures/Wallpapers"
HISTORY_FILE="$HOME/.cache/wallpaper_history.txt"

mkdir -p "$(dirname "$HISTORY_FILE")"
touch "$HISTORY_FILE"

FILE_LIST=$(find "$WALLPAPERS_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) -printf "%f\n" | sort)

if [ -z "$FILE_LIST" ]; then
    echo "No wallpapers found in $WALLPAPERS_DIR" >&2
    exit 1
fi

AVAILABLE_LIST=$(comm -23 <(echo "$FILE_LIST") <(sort "$HISTORY_FILE"))

if [ -z "$AVAILABLE_LIST" ]; then
    : > "$HISTORY_FILE"
    AVAILABLE_LIST="$FILE_LIST"
fi

SELECTED_FILE=$(echo "$AVAILABLE_LIST" | shuf -n 1)

if [ -z "$SELECTED_FILE" ]; then
    echo "No wallpaper available to select." >&2
    exit 1
fi

echo "$SELECTED_FILE" >> "$HISTORY_FILE"

WALL="$WALLPAPERS_DIR/$SELECTED_FILE"

if [ ! -f "$WALL" ]; then
    echo "Wallpaper not found: $WALL"
    exit 1
fi

awww img --transition-type center --transition-step 90 "$WALL"
echo "Wallpaper set successfully"