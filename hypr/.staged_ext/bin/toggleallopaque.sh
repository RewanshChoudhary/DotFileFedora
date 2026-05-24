#!/usr/bin/env bash

# Toggle opacity for all windows
# Switches between normal (0.85/0.85) and fully opaque (1.0/1.0)

state_file="${XDG_RUNTIME_DIR:-/tmp}/hypr-all-opacity-toggle"

if [[ -f "$state_file" ]]; then
    rm "$state_file"
    hyprctl keyword decoration:active_opacity 0.85 >/dev/null
    hyprctl keyword decoration:inactive_opacity 0.85 >/dev/null
    notify-send -u low "Opacity restored" "Windows: 0.85 / 0.85"
else
    touch "$state_file"
    hyprctl keyword decoration:active_opacity 1.0 >/dev/null
    hyprctl keyword decoration:inactive_opacity 1.0 >/dev/null
    notify-send -u low "Full opacity enabled" "All windows: 1.0 / 1.0"
fi
