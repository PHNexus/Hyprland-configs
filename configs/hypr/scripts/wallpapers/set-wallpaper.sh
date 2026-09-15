#!/bin/bash
set -eu

WALL_DIR="$HOME/Pictures/Wallpapers"
HISTORY_FILE="$HOME/.cache/wallpaper_history.txt"
SET_SCRIPT="$HOME/.config/hypr/scripts/wallpapers/set.sh"

if [ ! -d "$WALL_DIR" ]; then
    echo "Cannot find directory with wallpapers: $WALL_DIR"
    exit 1
fi

mkdir -p "$(dirname "$HISTORY_FILE")"
touch "$HISTORY_FILE"

FILE_LIST=$(find "$WALL_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) -printf "%f\n" | sort)

if [ -z "$FILE_LIST" ]; then
    echo "Nenhum wallpaper encontrado em $WALL_DIR" >&2
    exit 1
fi

AVAILABLE_LIST=$(comm -23 <(echo "$FILE_LIST") <(sort "$HISTORY_FILE"))

if [ -z "$AVAILABLE_LIST" ]; then
    echo "Todos os wallpapers foram usados. Reiniciando o ciclo..."
    > "$HISTORY_FILE"
    AVAILABLE_LIST="$FILE_LIST"
fi

SELECTED_FILE=$(echo "$AVAILABLE_LIST" | wofi --dmenu --prompt "Select wallpaper")

[ -z "$SELECTED_FILE" ] && exit 1

echo "$SELECTED_FILE" >> "$HISTORY_FILE"

WALL="$WALL_DIR/$SELECTED_FILE"
echo "Setting wallpaper: $SELECTED_FILE"

"$SET_SCRIPT" "$WALL"

echo "All done!"