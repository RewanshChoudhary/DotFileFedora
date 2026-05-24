#!/usr/bin/env bash

set -euo pipefail

action="${1:-}"
save_dir="${XDG_SCREENSHOTS_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots}"
mkdir -p "${save_dir}"

timestamp="$(date +'%y%m%d_%Hh%Mm%Ss_screenshot.png')"
save_file="${save_dir}/${timestamp}"
temp_file="/tmp/hyprland-screenshot.png"

cleanup() {
    rm -f "${temp_file}"
}

notify_saved() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Hyprland" -i "${save_file}" "Screenshot saved" "${save_file}"
    fi
}

capture() {
    local wait_seconds="$1"
    local target="$2"
    local use_swappy="$3"

    if [ "${use_swappy}" = "1" ] && command -v swappy >/dev/null 2>&1; then
        if [ -n "${wait_seconds}" ]; then
            grimblast --wait "${wait_seconds}" copysave "${target}" "${temp_file}"
        else
            grimblast copysave "${target}" "${temp_file}"
        fi
        swappy -f "${temp_file}"
        return
    fi

    if [ -n "${wait_seconds}" ]; then
        grimblast --wait "${wait_seconds}" copysave "${target}" "${save_file}"
    else
        grimblast copysave "${target}" "${save_file}"
    fi
    notify_saved
}

trap cleanup EXIT

case "${action}" in
    now) capture "" screen 0 ;;
    area) capture "" area 0 ;;
    in5) capture "5" screen 0 ;;
    in10) capture "10" screen 0 ;;
    active) capture "" active 0 ;;
    swappy) capture "" area 1 ;;
    *)
        printf 'usage: %s {now|area|in5|in10|active|swappy}\n' "$(basename "$0")" >&2
        exit 1
        ;;
esac
