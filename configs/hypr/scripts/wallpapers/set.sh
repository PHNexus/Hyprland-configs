#!/bin/bash
set -eu

WALL="$1"

if [ ! -f "$WALL" ]; then
    echo "Wallpaper não encontrado: $WALL"
    exit 1
fi

awww img --transition-type center --transition-step 90 "$WALL"
echo "Wallpaper set successfully"