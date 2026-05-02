#!/usr/bin/env bash
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

ROFI_THEME="$HOME/.config/rofi/config-nucleus-quicksettings.rasi"
LOCAL_THEME_DIR="$HOME/.config/hyprwave/themes"
USER_THEME_DIR="$HOME/.local/share/hyprwave/themes"

have() {
    command -v "$1" >/dev/null 2>&1
}

notify_low() {
    local title="${1:-HyprWave Theme}"
    local body="${2:-}"
    if have notify-send; then
        notify-send -u low "$title" "$body"
    fi
}

if ! have rofi; then
    notify_low "HyprWave Theme" "rofi is not installed"
    exit 1
fi

if [[ ! -d "$LOCAL_THEME_DIR" ]]; then
    notify_low "HyprWave Theme" "No local theme directory: $LOCAL_THEME_DIR"
    exit 1
fi

mapfile -t themes < <(find "$LOCAL_THEME_DIR" -maxdepth 1 -type f -name '*.css' -printf '%f\n' | sed 's/\.css$//' | sort -V)
if ((${#themes[@]} == 0)); then
    notify_low "HyprWave Theme" "No Nucleus themes found in $LOCAL_THEME_DIR"
    exit 1
fi

choice="$(printf '%s\n' "${themes[@]}" | rofi -dmenu -i -no-custom -config "$ROFI_THEME" -p "HyprWave Theme" -mesg "<span foreground='#E5B6F2'>Choose a Nucleus shell palette for HyprWave.</span>")"
[[ -z "${choice:-}" ]] && exit 0

src="$LOCAL_THEME_DIR/$choice.css"
if [[ ! -f "$src" ]]; then
    notify_low "HyprWave Theme" "Theme file missing: $choice.css"
    exit 1
fi

mkdir -p "$USER_THEME_DIR"
cp -f "$src" "$USER_THEME_DIR/$choice.css"

if have hyprwave-toggle; then
    if hyprwave-toggle set-theme "$choice" >/dev/null 2>&1; then
        notify_low "HyprWave Theme" "Applied: $choice"
    else
        notify_low "HyprWave Theme" "Installed $choice. Run: hyprwave-toggle set-theme $choice"
    fi
else
    notify_low "HyprWave Theme" "Theme installed. hyprwave-toggle is not available to apply it now."
fi
