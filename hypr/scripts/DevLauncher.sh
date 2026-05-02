#!/usr/bin/env bash
# Developer workflow launcher for waybar.

set -euo pipefail

config_file="$HOME/.config/hypr/UserConfigs/01-UserDefaults.conf"
rofi_theme="$HOME/.config/rofi/config-edit.rasi"
iDIR="$HOME/.config/swaync/images"

notify_msg() {
    local level="$1"
    local title="$2"
    local body="$3"
    local icon="$iDIR/info.png"

    if [[ "$level" == "error" ]]; then
        icon="$iDIR/error.png"
    fi

    notify-send -u low -i "$icon" "$title" "$body"
}

term="kitty"
if [[ -f "$config_file" ]]; then
    tmp_config_file="$(mktemp)"
    sed 's/^\$//g; s/ = /=/g' "$config_file" > "$tmp_config_file"
    # shellcheck disable=SC1090
    source "$tmp_config_file"
    rm -f "$tmp_config_file"
fi

term_bin="${term%% *}"
projects_dir="$HOME/Projects"
if [[ ! -d "$projects_dir" ]]; then
    projects_dir="$HOME"
fi

run_in_terminal() {
    local command_text="$1"
    if ! command -v "$term_bin" >/dev/null 2>&1; then
        notify_msg error "Dev Launcher" "Terminal '$term_bin' not found"
        exit 1
    fi
    eval "$term -e bash -lc '$command_text'" >/dev/null 2>&1 &
}

launch_app() {
    local app="$1"
    shift
    if command -v "$app" >/dev/null 2>&1; then
        "$app" "$@" >/dev/null 2>&1 &
    else
        notify_msg error "Dev Launcher" "Command not found: $app"
    fi
}

menu() {
    cat <<'MENU'
󰆍  Terminal
  Neovim
  Lazygit
󰓓  Btop
  GitUI
  Cursor IDE
󰨞  VS Code
  Projects Folder
MENU
}

choice="$(menu | rofi -i -dmenu -config "$rofi_theme" -mesg "Developer Launcher")"
[[ -z "$choice" ]] && exit 0

case "$choice" in
    "󰆍  Terminal")
        if command -v "$term_bin" >/dev/null 2>&1; then
            eval "$term" >/dev/null 2>&1 &
        else
            notify_msg error "Dev Launcher" "Terminal '$term_bin' not found"
        fi
        ;;
    "  Neovim")
        run_in_terminal "nvim"
        ;;
    "  Lazygit")
        run_in_terminal "lazygit"
        ;;
    "󰓓  Btop")
        run_in_terminal "btop"
        ;;
    "  GitUI")
        run_in_terminal "gitui"
        ;;
    "  Cursor IDE")
        launch_app cursor "$projects_dir"
        ;;
    "󰨞  VS Code")
        launch_app code "$projects_dir"
        ;;
    "  Projects Folder")
        launch_app xdg-open "$projects_dir"
        ;;
    *)
        exit 0
        ;;
esac
