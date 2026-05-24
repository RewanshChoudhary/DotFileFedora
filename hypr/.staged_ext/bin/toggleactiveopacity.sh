#!/usr/bin/env bash

set -euo pipefail

state_file="${XDG_RUNTIME_DIR:-/tmp}/hypr-active-opacity-overrides"

active_window_json="$(hyprctl -j activewindow 2>/dev/null || true)"
window_address="$(printf '%s' "${active_window_json}" | jq -r '.address // empty')"
window_class="$(printf '%s' "${active_window_json}" | jq -r '.class // "window"')"

if [[ -z "${window_address}" ]]; then
    exit 0
fi

touch "${state_file}"

if grep -Fxq "${window_address}" "${state_file}"; then
    hyprctl setprop "address:${window_address}" opacity unset >/dev/null
    hyprctl setprop "address:${window_address}" opacity_inactive unset >/dev/null
    hyprctl setprop "address:${window_address}" opacity_fullscreen unset >/dev/null
    hyprctl setprop "address:${window_address}" opacity_override unset >/dev/null
    hyprctl setprop "address:${window_address}" opacity_inactive_override unset >/dev/null
    hyprctl setprop "address:${window_address}" opacity_fullscreen_override unset >/dev/null

    grep -Fxv "${window_address}" "${state_file}" > "${state_file}.tmp" || true
    mv "${state_file}.tmp" "${state_file}"

    notify-send -u low "Default opacity restored" "${window_class}"
    exit 0
fi

hyprctl setprop "address:${window_address}" opacity 1 >/dev/null
hyprctl setprop "address:${window_address}" opacity_inactive 1 >/dev/null
hyprctl setprop "address:${window_address}" opacity_fullscreen 1 >/dev/null
hyprctl setprop "address:${window_address}" opacity_override 1 >/dev/null
hyprctl setprop "address:${window_address}" opacity_inactive_override 1 >/dev/null
hyprctl setprop "address:${window_address}" opacity_fullscreen_override 1 >/dev/null

printf '%s\n' "${window_address}" >> "${state_file}"
sort -u "${state_file}" -o "${state_file}"

notify-send -u low "Full opacity enabled" "${window_class}"
