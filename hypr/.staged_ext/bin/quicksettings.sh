#!/usr/bin/env bash

set -euo pipefail

declare -a labels=()
declare -A commands=()

add_item() {
    local label="$1"
    local cmd="$2"
    local probe="$3"
    if command -v "${probe}" >/dev/null 2>&1; then
        labels+=("${label}")
        commands["${label}"]="${cmd}"
    fi
}

add_item "Audio" "pavucontrol" "pavucontrol"
add_item "Bluetooth" "blueman-manager" "blueman-manager"
add_item "Network" "nm-connection-editor" "nm-connection-editor"
add_item "GTK Theme" "nwg-look" "nwg-look"
add_item "Qt Theme" "qt6ct" "qt6ct"
add_item "Power Menu" "$HOME/.local/share/bin/logoutlaunch.sh" "wlogout"

[ "${#labels[@]}" -gt 0 ] || exit 0

choice="$(
    printf '%s\n' "${labels[@]}" |
        rofi -dmenu -p "Quick settings"
)"

[ -n "${choice}" ] || exit 0
exec ${commands["${choice}"]}
