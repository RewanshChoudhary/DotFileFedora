#!/usr/bin/env bash

set -euo pipefail

current_passes="$(hyprctl -j getoption decoration:blur:passes | jq -r '.int')"

if [[ "${current_passes}" == "3" ]]; then
    hyprctl keyword decoration:blur:size 2 >/dev/null
    hyprctl keyword decoration:blur:passes 1 >/dev/null
    notify-send -u low "Low blur enabled"
    exit 0
fi

hyprctl keyword decoration:blur:size 6 >/dev/null
hyprctl keyword decoration:blur:passes 3 >/dev/null
notify-send -u low "Medium blur enabled"
