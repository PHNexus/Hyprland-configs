#!/bin/bash
set -eu

WALL_DIR="$HOME/Pictures/Wallpapers"


if [ ! -d "$WALL_DIR" ]; then
    echo "Cannot find directory with wallpapers: $WALL_DIR"
    exit 1
fi

FILE_LIST=$(find "$WALL_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) -printf "%f\n")

SELECTED_FILE=$(echo "$FILE_LIST" | wofi --dmenu --prompt "Select wallpaper")

[ -z "$SELECTED_FILE" ] && exit 1

WALL="$WALL_DIR/$SELECTED_FILE"
echo "Setting wallpaper: $SELECTED_FILE"
awww img --transition-type center --transition-step 90 "$WALL"
echo "Wallpaper set successfully"

if command -v wal >/dev/null 2>&1; then
    echo "Applying pywal colors..."
    wal -i "$WALL"
    echo "Pywal applied successfully"
    
    
    export PATH="$HOME/.local/bin:$PATH:/usr/local/bin"
    
    if command -v pywalfox >/dev/null 2>&1; then
        echo "Updating pywalfox..."
        pywalfox update &
    else
        echo "pywalfox not found in PATH"
    fi
    
    
    KEYBOARD_SCRIPT="$HOME/.config/keyboard/set-color-keyboard.sh"
    if [ -x "$KEYBOARD_SCRIPT" ]; then
        echo "Updating keyboard colors..."
        bash "$KEYBOARD_SCRIPT" &
    else
        echo "Keyboard color script not found or not executable: $KEYBOARD_SCRIPT"
    fi
    
    wait
    
else
    echo "Pywal not installed, skipping"
fi
echo "All done!"
