#!/bin/bash
set -eu

CHOOSE_RANDOM="$HOME/.config/hypr/scripts/wallpapers/random.sh"
SET_SCRIPT="$HOME/.config/hypr/scripts/wallpapers/set.sh"

"$SET_SCRIPT" "$("$CHOOSE_RANDOM")"