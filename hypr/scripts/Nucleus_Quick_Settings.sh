#!/usr/bin/env bash
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

ROFI_THEME="$HOME/.config/rofi/config-nucleus-quicksettings.rasi"
SCRIPTS_DIR="$HOME/.config/hypr/scripts"
LEGACY_MENU="$SCRIPTS_DIR/Kool_Quick_Settings.sh"
HYPRWAVE_CONTROL="$SCRIPTS_DIR/HyprWave_Control.sh"
HYPRWAVE_THEME_SELECTOR="$SCRIPTS_DIR/HyprWave_ThemeSelector.sh"
NUCLEUS_THEME_SELECTOR="$SCRIPTS_DIR/Nucleus_Shell_ThemeSelector.sh"
THEME_STATE_FILE="$SCRIPTS_DIR/.nucleus_theme.env"
OVERVIEW_TOGGLE="$SCRIPTS_DIR/OverviewToggle.sh"
CLIP_MANAGER="$SCRIPTS_DIR/ClipManager.sh"
SCREENSHOT_TOOL="$SCRIPTS_DIR/ScreenShot.sh"
ROFI_SEARCH="$SCRIPTS_DIR/RofiSearch.sh"
LOCK_SCREEN="$SCRIPTS_DIR/LockScreen.sh"
KEY_HINTS="$SCRIPTS_DIR/KeyHints.sh"
START_QUICKSHELL="$SCRIPTS_DIR/StartQuickshell.sh"

STATUS_CMD_TIMEOUT="${STATUS_CMD_TIMEOUT:-0.35s}"
BT_CMD_TIMEOUT="${BT_CMD_TIMEOUT:-3s}"

# nucleus-shell palette (quickshell/overview/common/Appearance.qml defaults)
COL_TEXT="#EAE0E7"
COL_MUTED="#CFC3CD"
COL_PRIMARY="#E5B6F2"
COL_ON="#F9D8FF"
COL_OFF="#FFB4AB"
COL_SECURE="#F2DCF3"
COL_OPEN="#CFC3CD"
COL_DIM="#988E97"
COL_ACTION="#D5C0D7"

# Override defaults if a saved theme exists.
if [[ -f "$THEME_STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$THEME_STATE_FILE"
fi

MENU_ROWS=()

have() {
    command -v "$1" >/dev/null 2>&1
}

run_with_timeout() {
    local limit="${1:-0.35s}"
    shift
    if have timeout; then
        timeout "$limit" "$@" 2>/dev/null
    else
        "$@" 2>/dev/null
    fi
}

notify_low() {
    local title="${1:-Quick Settings}"
    local body="${2:-}"
    if [[ "${NUCLEUS_QS_SILENT:-0}" == "1" ]]; then
        return
    fi
    if have notify-send; then
        notify-send -u low "$title" "$body"
    fi
}

escape_markup() {
    local text="${1:-}"
    text="${text//&/&amp;}"
    text="${text//</&lt;}"
    text="${text//>/&gt;}"
    printf '%s' "$text"
}

state_chip() {
    case "${1:-na}" in
        on) printf "<span foreground='%s'><b>Enabled</b></span>" "$COL_ON" ;;
        off) printf "<span foreground='%s'><b>Disabled</b></span>" "$COL_OFF" ;;
        *) printf "<span foreground='%s'><b>Unavailable</b></span>" "$COL_MUTED" ;;
    esac
}

wifi_signal_label() {
    local signal="${1:-0}"
    if [[ ! "$signal" =~ ^[0-9]+$ ]]; then
        signal=0
    fi
    if (( signal >= 80 )); then
        printf 'Excellent'
    elif (( signal >= 60 )); then
        printf 'Good'
    elif (( signal >= 40 )); then
        printf 'Fair'
    else
        printf 'Weak'
    fi
}

wifi_enabled() {
    have nmcli || return 1
    local state
    state="$(run_with_timeout "$STATUS_CMD_TIMEOUT" nmcli radio wifi | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    [[ "$state" == "enabled" || "$state" == "on" ]]
}

wifi_active_info() {
    have nmcli || return 0
    local active_line parsed ssid signal
    active_line="$(run_with_timeout "$STATUS_CMD_TIMEOUT" nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | awk -F: '$1=="yes"{print; exit}')"
    [[ -z "$active_line" ]] && return 0
    parsed="${active_line//\\:/$'\x1f'}"
    IFS=':' read -r _ ssid signal <<<"$parsed"
    ssid="${ssid//$'\x1f'/:}"
    printf '%s|%s' "$ssid" "$signal"
}

wifi_signal_icon() {
    local signal="${1:-0}"
    if [[ ! "$signal" =~ ^[0-9]+$ ]]; then
        signal=0
    fi
    if (( signal >= 75 )); then
        printf '󰤨'
    elif (( signal >= 50 )); then
        printf '󰤥'
    elif (( signal >= 25 )); then
        printf '󰤢'
    else
        printf '󰤯'
    fi
}

toggle_wifi() {
    if ! have nmcli; then
        notify_low "Wi-Fi" "nmcli is not installed"
        return
    fi

    if wifi_enabled; then
        if nmcli radio wifi off >/dev/null 2>&1; then
            notify_low "Wi-Fi" "Disabled"
        else
            notify_low "Wi-Fi" "Failed to disable"
        fi
    else
        if nmcli radio wifi on >/dev/null 2>&1; then
            notify_low "Wi-Fi" "Enabled"
        else
            notify_low "Wi-Fi" "Failed to enable"
        fi
    fi
}

wifi_networks_menu() {
    if ! have nmcli; then
        notify_low "Wi-Fi" "nmcli is not installed"
        return
    fi

    if ! wifi_enabled; then
        nmcli radio wifi on >/dev/null 2>&1 || {
            notify_low "Wi-Fi" "Could not enable Wi-Fi"
            return
        }
    fi

    local -a rows=()
    local -a ssids=()
    local -a secure_flags=()
    local line parsed in_use ssid signal security selection signal_icon signal_quality security_text

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        parsed="${line//\\:/$'\x1f'}"
        IFS=':' read -r in_use ssid signal security _ <<<"$parsed"
        ssid="${ssid//$'\x1f'/:}"
        security="${security//$'\x1f'/:}"
        [[ -z "$ssid" ]] && continue
        signal_icon="$(wifi_signal_icon "$signal")"

        signal_quality="$(wifi_signal_label "$signal")"
        if [[ -n "$security" && "$security" != "--" ]]; then
            security_text="Secured (${security})"
        else
            security_text="Open network"
        fi

        if [[ "$in_use" == "*" ]]; then
            rows+=("${signal_icon}  <b>$(escape_markup "$ssid")</b> · <span foreground='${COL_ON}'>Connected now</span> · <span foreground='${COL_MUTED}'>${signal_quality} (${signal:-0}%)</span> · <span foreground='${COL_SECURE}'>$(escape_markup "$security_text")</span>")
        elif [[ -n "$security" && "$security" != "--" ]]; then
            rows+=("${signal_icon}  <b>$(escape_markup "$ssid")</b> · <span foreground='${COL_MUTED}'>${signal_quality} (${signal:-0}%)</span> · <span foreground='${COL_SECURE}'>$(escape_markup "$security_text")</span>")
        else
            rows+=("${signal_icon}  <b>$(escape_markup "$ssid")</b> · <span foreground='${COL_MUTED}'>${signal_quality} (${signal:-0}%)</span> · <span foreground='${COL_OPEN}'>Open network (no password)</span>")
        fi

        ssids+=("$ssid")
        if [[ -n "$security" && "$security" != "--" ]]; then
            secure_flags+=("1")
        else
            secure_flags+=("0")
        fi
    done < <(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto 2>/dev/null)

    if ((${#rows[@]} == 0)); then
        notify_low "Wi-Fi" "No networks found"
        return
    fi

    selection="$(printf '%s\n' "${rows[@]}" | rofi -dmenu -i -markup-rows -no-custom -config "$ROFI_THEME" -theme-str 'window { width: 1140px; } listview { columns: 1; lines: 12; }' -p "Wi-Fi Networks" -mesg "<span foreground=\"${COL_PRIMARY}\">Press Enter to connect. Secured networks will ask for a password.</span>" -format i)"
    [[ -z "$selection" ]] && return
    [[ "$selection" =~ ^[0-9]+$ ]] || return

    local ssid_choice="${ssids[$selection]}"
    local secure_choice="${secure_flags[$selection]}"

    if [[ "$secure_choice" == "1" ]]; then
        if nmcli dev wifi connect "$ssid_choice" >/dev/null 2>&1; then
            notify_low "Wi-Fi" "Connected to $ssid_choice"
            return
        fi

        local password
        password="$(rofi -dmenu -password -config "$ROFI_THEME" -p "Password for $ssid_choice")"
        [[ -z "$password" ]] && return

        if nmcli dev wifi connect "$ssid_choice" password "$password" >/dev/null 2>&1; then
            notify_low "Wi-Fi" "Connected to $ssid_choice"
        else
            notify_low "Wi-Fi" "Failed to connect to $ssid_choice"
        fi
    else
        if nmcli dev wifi connect "$ssid_choice" >/dev/null 2>&1; then
            notify_low "Wi-Fi" "Connected to $ssid_choice"
        else
            notify_low "Wi-Fi" "Failed to connect to $ssid_choice"
        fi
    fi
}

bluetooth_enabled() {
    if have nmcli; then
        local state
        state="$(run_with_timeout "$STATUS_CMD_TIMEOUT" nmcli radio bluetooth | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
        if [[ "$state" == "enabled" || "$state" == "on" ]]; then
            return 0
        fi
        if [[ "$state" == "disabled" || "$state" == "off" ]]; then
            return 1
        fi
    fi

    have bluetoothctl || return 1
    [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] || return 1
    run_with_timeout "$STATUS_CMD_TIMEOUT" bluetoothctl show | grep -q "Powered: yes"
}

ensure_bluetooth_stack() {
    if have rfkill; then
        run_with_timeout "$BT_CMD_TIMEOUT" rfkill unblock bluetooth >/dev/null 2>&1 || true
    fi

    if ! have systemctl; then
        return 0
    fi

    if run_with_timeout "$BT_CMD_TIMEOUT" systemctl is-active --quiet bluetooth.service; then
        return 0
    fi

    if run_with_timeout "$BT_CMD_TIMEOUT" systemctl start bluetooth.service >/dev/null 2>&1; then
        return 0
    fi

    if have sudo && run_with_timeout "$BT_CMD_TIMEOUT" sudo -n systemctl start bluetooth.service >/dev/null 2>&1; then
        return 0
    fi

    if have pkexec; then
        run_with_timeout "$BT_CMD_TIMEOUT" pkexec systemctl start bluetooth.service >/dev/null 2>&1 || true
    fi
}

bluetooth_power_on() {
    ensure_bluetooth_stack

    if have nmcli && run_with_timeout "$BT_CMD_TIMEOUT" nmcli radio bluetooth on >/dev/null 2>&1; then
        return 0
    fi

    if have bluetoothctl && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        run_with_timeout "$BT_CMD_TIMEOUT" bluetoothctl power on >/dev/null 2>&1 && return 0
    fi

    return 1
}

bluetooth_power_off() {
    if have nmcli && run_with_timeout "$BT_CMD_TIMEOUT" nmcli radio bluetooth off >/dev/null 2>&1; then
        return 0
    fi

    if have bluetoothctl && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        run_with_timeout "$BT_CMD_TIMEOUT" bluetoothctl power off >/dev/null 2>&1 && return 0
    fi

    return 1
}

toggle_bluetooth() {
    if ! have nmcli && ! have bluetoothctl; then
        notify_low "Bluetooth" "Neither nmcli nor bluetoothctl is installed"
        return
    fi

    if bluetooth_enabled; then
        if bluetooth_power_off; then
            notify_low "Bluetooth" "Disabled"
        else
            notify_low "Bluetooth" "Failed to disable"
        fi
    else
        if bluetooth_power_on; then
            notify_low "Bluetooth" "Enabled"
        else
            notify_low "Bluetooth" "Failed to enable (check rfkill/bluetooth.service)"
        fi
    fi
}

open_bluetooth_manager() {
    if have blueman-manager; then
        blueman-manager >/dev/null 2>&1 &
    elif have blueberry; then
        blueberry >/dev/null 2>&1 &
    else
        notify_low "Bluetooth" "Install blueman for a device manager"
    fi
}

bluetooth_devices_menu() {
    if ! have bluetoothctl; then
        notify_low "Bluetooth" "bluetoothctl is not installed"
        return
    fi
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        notify_low "Bluetooth" "Session bus is not available"
        return
    fi

    local -a rows=()
    local -a addrs=()
    local -a connected=()
    local line addr name selection offset bt_power_hint

    if bluetooth_enabled; then
        bt_power_hint="currently enabled"
    else
        bt_power_hint="currently disabled"
    fi

    rows+=("  <b>Bluetooth Power</b> · <span foreground='${COL_ACTION}'>${bt_power_hint} · press Enter to toggle</span>")
    rows+=("󰂲  <b>Open Bluetooth Manager</b> · <span foreground='${COL_ACTION}'>pair, trust, remove devices</span>")

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        addr="${line%% *}"
        name="${line#* }"
        [[ -z "$addr" || -z "$name" || "$addr" == "$name" ]] && continue

        if bluetoothctl info "$addr" 2>/dev/null | grep -q "Connected: yes"; then
            rows+=("󰂱  <b>$(escape_markup "$name")</b> · <span foreground='${COL_ON}'>Connected</span> · <span foreground='${COL_MUTED}'>press Enter to disconnect</span>")
            connected+=("1")
        else
            rows+=("  <b>$(escape_markup "$name")</b> · <span foreground='${COL_MUTED}'>Not connected</span> · <span foreground='${COL_MUTED}'>press Enter to connect</span>")
            connected+=("0")
        fi
        addrs+=("$addr")
    done < <(bluetoothctl devices 2>/dev/null | sed -n 's/^Device //p')

    selection="$(printf '%s\n' "${rows[@]}" | rofi -dmenu -i -markup-rows -no-custom -config "$ROFI_THEME" -theme-str 'window { width: 1020px; } listview { columns: 1; lines: 12; }' -p "Bluetooth Devices" -mesg "<span foreground=\"${COL_PRIMARY}\">Press Enter on a device to connect or disconnect.</span>" -format i)"
    [[ -z "$selection" ]] && return
    [[ "$selection" =~ ^[0-9]+$ ]] || return

    case "$selection" in
        0)
            toggle_bluetooth
            return
            ;;
        1)
            open_bluetooth_manager
            return
            ;;
    esac

    offset=$((selection - 2))
    if ((offset < 0 || offset >= ${#addrs[@]})); then
        return
    fi

        addr="${addrs[$offset]}"
    name="$(bluetoothctl info "$addr" 2>/dev/null | sed -n 's/^\\s*Name: //p' | head -n1)"
    [[ -z "$name" ]] && name="$addr"

    if [[ "${connected[$offset]}" == "1" ]]; then
        if bluetoothctl disconnect "$addr" >/dev/null 2>&1; then
            notify_low "Bluetooth" "Disconnected $name"
        else
            notify_low "Bluetooth" "Failed to disconnect $name"
        fi
    else
        if ! bluetooth_enabled; then
            bluetooth_power_on >/dev/null 2>&1 || true
        fi
        if bluetoothctl connect "$addr" >/dev/null 2>&1; then
            notify_low "Bluetooth" "Connected $name"
        else
            notify_low "Bluetooth" "Failed to connect $name"
        fi
    fi
}

airplane_mode_on() {
    have nmcli || return 1
    local radios
    radios="$(run_with_timeout "$STATUS_CMD_TIMEOUT" nmcli radio all | tr '[:upper:]' '[:lower:]')"
    [[ -z "$radios" ]] && return 1
    grep -Eq 'enabled|on' <<<"$radios" && return 1
    return 0
}

toggle_airplane_mode() {
    if ! have nmcli; then
        notify_low "Airplane Mode" "nmcli is not installed"
        return
    fi

    if airplane_mode_on; then
        if nmcli radio all on >/dev/null 2>&1; then
            notify_low "Airplane Mode" "Disabled"
        else
            notify_low "Airplane Mode" "Failed to disable"
        fi
    else
        if nmcli radio all off >/dev/null 2>&1; then
            notify_low "Airplane Mode" "Enabled"
        else
            notify_low "Airplane Mode" "Failed to enable"
        fi
    fi
}

toggle_night_light() {
    if [[ -x "$SCRIPTS_DIR/Hyprsunset.sh" ]]; then
        "$SCRIPTS_DIR/Hyprsunset.sh" toggle >/dev/null 2>&1
    else
        notify_low "Night Light" "Hyprsunset script is missing"
    fi
}

toggle_idle_timeout() {
    if [[ -x "$SCRIPTS_DIR/Hypridle.sh" ]]; then
        "$SCRIPTS_DIR/Hypridle.sh" toggle >/dev/null 2>&1
        if pgrep -x hypridle >/dev/null 2>&1; then
            notify_low "Idle Timeout" "Enabled"
        else
            notify_low "Idle Timeout" "Disabled"
        fi
    else
        notify_low "Idle Timeout" "Hypridle script is missing"
    fi
}

cycle_power_profile() {
    if ! have powerprofilesctl; then
        notify_low "Power Profile" "powerprofilesctl is not installed"
        return
    fi

    local current target
    current="$(powerprofilesctl get 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    case "$current" in
        performance) target="balanced" ;;
        balanced) target="power-saver" ;;
        power-saver) target="performance" ;;
        *) target="balanced" ;;
    esac

    if powerprofilesctl set "$target" >/dev/null 2>&1; then
        notify_low "Power Profile" "Switched to $target"
    else
        notify_low "Power Profile" "Could not set $target"
    fi
}

hyprwave_running() {
    pgrep -x hyprwave >/dev/null 2>&1
}

start_hyprwave() {
    if ! have hyprwave; then
        notify_low "HyprWave" "hyprwave is not installed"
        return 1
    fi
    if hyprwave_running; then
        return 0
    fi
    hyprwave >/dev/null 2>&1 &
    sleep 0.2
    if hyprwave_running; then
        return 0
    fi
    notify_low "HyprWave" "Could not start hyprwave"
    return 1
}

hyprwave_action() {
    local action="${1:-visibility}"
    if ! hyprwave_running; then
        start_hyprwave || return 1
    fi

    if have hyprwave-toggle; then
        hyprwave-toggle "$action" >/dev/null 2>&1 || true
        return 0
    fi

    # Fallback signals if hyprwave-toggle is unavailable.
    case "$action" in
        visibility) pkill -SIGUSR1 -x hyprwave >/dev/null 2>&1 || true ;;
        expand) pkill -SIGUSR2 -x hyprwave >/dev/null 2>&1 || true ;;
        play) pkill -SIGRTMIN -x hyprwave >/dev/null 2>&1 || true ;;
        next) pkill -SIGRTMIN+1 -x hyprwave >/dev/null 2>&1 || true ;;
        prev) pkill -SIGRTMIN+2 -x hyprwave >/dev/null 2>&1 || true ;;
        *) true ;;
    esac
}

hyprwave_summary_line() {
    if ! have hyprwave; then
        printf "<span foreground='%s'>hyprwave not installed</span>" "$COL_MUTED"
        return
    fi

    if hyprwave_running; then
        printf "<span foreground='%s'>Running</span> · <span foreground='%s'>Press Enter to show/hide widget</span>" "$COL_ON" "$COL_MUTED"
    else
        printf "<span foreground='%s'>Stopped</span> · <span foreground='%s'>Press Enter to launch widget</span>" "$COL_MUTED" "$COL_MUTED"
    fi
}

run_hyprwave_widget() {
    if ! have hyprwave; then
        notify_low "HyprWave" "hyprwave is not installed"
        return
    fi
    if [[ -x "$HYPRWAVE_CONTROL" ]]; then
        "$HYPRWAVE_CONTROL" toggle >/dev/null 2>&1 || true
    else
        hyprwave_action "visibility"
    fi
}

run_hyprwave_theme_selector() {
    if [[ -x "$HYPRWAVE_THEME_SELECTOR" ]]; then
        "$HYPRWAVE_THEME_SELECTOR" >/dev/null 2>&1 || true
    else
        notify_low "HyprWave Theme" "Theme selector script is missing"
    fi
}

run_nucleus_theme_selector() {
    if [[ -x "$NUCLEUS_THEME_SELECTOR" ]]; then
        "$NUCLEUS_THEME_SELECTOR" >/dev/null 2>&1 || true
    else
        notify_low "Nucleus Theme" "Theme selector script is missing"
    fi
}

run_overview_toggle() {
    if [[ -x "$OVERVIEW_TOGGLE" ]]; then
        "$OVERVIEW_TOGGLE" >/dev/null 2>&1 || true
    else
        notify_low "Overview" "Overview toggle script is missing"
    fi
}

run_quickshell_profile() {
    local profile="${1:-}"
    if [[ ! -x "$START_QUICKSHELL" ]]; then
        notify_low "QuickShell" "StartQuickshell.sh is missing"
        return
    fi
    if "$START_QUICKSHELL" "$profile" >/dev/null 2>&1; then
        notify_low "QuickShell" "Switched to profile: $profile"
    else
        notify_low "QuickShell" "Failed to switch profile: $profile"
    fi
}

run_overview_shell() {
    run_quickshell_profile "overview"
}

run_nucleus_shell() {
    run_overview_shell
}

run_clipboard_manager() {
    if [[ -x "$CLIP_MANAGER" ]]; then
        "$CLIP_MANAGER" >/dev/null 2>&1 || true
    else
        notify_low "Clipboard" "ClipManager script is missing"
    fi
}

run_area_screenshot() {
    if [[ -x "$SCREENSHOT_TOOL" ]]; then
        "$SCREENSHOT_TOOL" --area >/dev/null 2>&1 || true
    else
        notify_low "Screenshot" "ScreenShot script is missing"
    fi
}

run_rofi_search() {
    if [[ -x "$ROFI_SEARCH" ]]; then
        "$ROFI_SEARCH" >/dev/null 2>&1 || true
    else
        notify_low "Web Search" "RofiSearch script is missing"
    fi
}

run_lock_screen() {
    if [[ -x "$LOCK_SCREEN" ]]; then
        "$LOCK_SCREEN" >/dev/null 2>&1 || true
    else
        notify_low "Lock Screen" "LockScreen script is missing"
    fi
}

run_key_hints() {
    if [[ -x "$KEY_HINTS" ]]; then
        "$KEY_HINTS" >/dev/null 2>&1 || true
    else
        notify_low "Key Hints" "KeyHints script is missing"
    fi
}

nucleus_features_menu() {
    local selection
    local -a rows=(
        "󰙀  <b>Launch Overview Shell</b> · <span foreground='${COL_ACTION}'>run qs -c overview</span>"
        "󱄅  <b>Reload Overview Shell</b> · <span foreground='${COL_ACTION}'>restart quickshell overview</span>"
        "  <b>Desktop Overview</b> · <span foreground='${COL_ACTION}'>toggle quickshell overview</span>"
        "  <b>Clipboard History</b> · <span foreground='${COL_ACTION}'>browse and copy from cliphist</span>"
        "󰄀  <b>Area Screenshot</b> · <span foreground='${COL_ACTION}'>select a region and copy image</span>"
        "󰖟  <b>Web Search</b> · <span foreground='${COL_ACTION}'>open search prompt in rofi</span>"
        "󰌌  <b>Keybind Cheat Sheet</b> · <span foreground='${COL_ACTION}'>open key hints</span>"
        "󰌾  <b>Lock Screen</b> · <span foreground='${COL_ACTION}'>lock the current session</span>"
    )

    selection="$(printf '%s\n' "${rows[@]}" | rofi -dmenu -i -markup-rows -no-custom -config "$ROFI_THEME" -theme-str 'window { width: 980px; } listview { columns: 1; lines: 10; }' -p "Nucleus Features" -mesg "<span foreground='${COL_PRIMARY}'>Extra actions from your Nucleus-style dotfiles.</span>" -format i)"
    [[ -z "$selection" ]] && return
    [[ "$selection" =~ ^[0-9]+$ ]] || return

    case "$selection" in
        0) run_overview_shell ;;
        1) run_nucleus_shell ;;
        2) run_overview_toggle ;;
        3) run_clipboard_manager ;;
        4) run_area_screenshot ;;
        5) run_rofi_search ;;
        6) run_key_hints ;;
        7) run_lock_screen ;;
    esac
}

collect_wifi_status() {
    local wifi_state="na"
    local wifi_detail="nmcli missing"

    if have nmcli; then
        if wifi_enabled; then
            wifi_state="on"
            local info ssid signal
            info="$(wifi_active_info)"
            if [[ "$info" == *"|"* ]]; then
                ssid="${info%%|*}"
                signal="${info#*|}"
                if [[ -n "$ssid" ]]; then
                    if [[ "$signal" =~ ^[0-9]+$ ]]; then
                        wifi_detail="$ssid (${signal}%)"
                    else
                        wifi_detail="$ssid"
                    fi
                else
                    wifi_detail="enabled"
                fi
            else
                wifi_detail="enabled"
            fi
        else
            wifi_state="off"
            wifi_detail="disabled"
        fi
    fi

    printf '%s\t%s\n' "$wifi_state" "$wifi_detail"
}

collect_bt_status() {
    local bt_state="na"
    local bt_detail="bluetooth missing"

    if have nmcli || have bluetoothctl; then
        if bluetooth_enabled; then
            bt_state="on"
            bt_detail="ready"
        else
            bt_state="off"
            bt_detail="disabled"
        fi
    fi

    printf '%s\t%s\n' "$bt_state" "$bt_detail"
}

collect_airplane_status() {
    local airplane_state="na"
    local airplane_detail="nmcli missing"

    if have nmcli; then
        if airplane_mode_on; then
            airplane_state="on"
            airplane_detail="all radios off"
        else
            airplane_state="off"
            airplane_detail="radios available"
        fi
    fi

    printf '%s\t%s\n' "$airplane_state" "$airplane_detail"
}

collect_night_status() {
    local night_state="na"
    local night_detail="hyprsunset missing"

    if [[ -x "$SCRIPTS_DIR/Hyprsunset.sh" ]]; then
        if pgrep -x hyprsunset >/dev/null 2>&1; then
            night_state="on"
            night_detail="warm color active"
        else
            night_state="off"
            night_detail="disabled"
        fi
    fi

    printf '%s\t%s\n' "$night_state" "$night_detail"
}

collect_idle_status() {
    local idle_state="na"
    local idle_detail="hypridle script missing"

    if [[ -x "$SCRIPTS_DIR/Hypridle.sh" ]]; then
        if pgrep -x hypridle >/dev/null 2>&1; then
            idle_state="on"
            idle_detail="timeouts active"
        else
            idle_state="off"
            idle_detail="inhibited"
        fi
    fi

    printf '%s\t%s\n' "$idle_state" "$idle_detail"
}

collect_power_status() {
    local power_text="N/A"
    if have powerprofilesctl; then
        power_text="$(run_with_timeout "$STATUS_CMD_TIMEOUT" powerprofilesctl get || printf "unknown")"
    fi
    printf '%s\n' "$power_text"
}

build_main_rows() {
    local tmpdir
    tmpdir="$(mktemp -d /tmp/nucleus-qs.XXXXXX 2>/dev/null || mktemp -d)"

    collect_wifi_status >"$tmpdir/wifi" &
    local pid_wifi=$!
    collect_bt_status >"$tmpdir/bt" &
    local pid_bt=$!
    collect_airplane_status >"$tmpdir/airplane" &
    local pid_airplane=$!
    collect_night_status >"$tmpdir/night" &
    local pid_night=$!
    collect_idle_status >"$tmpdir/idle" &
    local pid_idle=$!
    collect_power_status >"$tmpdir/power" &
    local pid_power=$!
    hyprwave_summary_line >"$tmpdir/hyprwave" &
    local pid_hyprwave=$!

    wait "$pid_wifi" 2>/dev/null || true
    wait "$pid_bt" 2>/dev/null || true
    wait "$pid_airplane" 2>/dev/null || true
    wait "$pid_night" 2>/dev/null || true
    wait "$pid_idle" 2>/dev/null || true
    wait "$pid_power" 2>/dev/null || true
    wait "$pid_hyprwave" 2>/dev/null || true

    local wifi_state="na" wifi_detail="unknown"
    local bt_state="na" bt_detail="unknown"
    local airplane_state="na" airplane_detail="unknown"
    local night_state="na" night_detail="unknown"
    local idle_state="na" idle_detail="unknown"
    local power_text="N/A"
    local hyprwave_summary

    if [[ -s "$tmpdir/wifi" ]]; then
        IFS=$'\t' read -r wifi_state wifi_detail <"$tmpdir/wifi" || true
    fi
    if [[ -s "$tmpdir/bt" ]]; then
        IFS=$'\t' read -r bt_state bt_detail <"$tmpdir/bt" || true
    fi
    if [[ -s "$tmpdir/airplane" ]]; then
        IFS=$'\t' read -r airplane_state airplane_detail <"$tmpdir/airplane" || true
    fi
    if [[ -s "$tmpdir/night" ]]; then
        IFS=$'\t' read -r night_state night_detail <"$tmpdir/night" || true
    fi
    if [[ -s "$tmpdir/idle" ]]; then
        IFS=$'\t' read -r idle_state idle_detail <"$tmpdir/idle" || true
    fi
    if [[ -s "$tmpdir/power" ]]; then
        power_text="$(<"$tmpdir/power")"
    fi
    if [[ -s "$tmpdir/hyprwave" ]]; then
        hyprwave_summary="$(<"$tmpdir/hyprwave")"
    else
        hyprwave_summary="$(hyprwave_summary_line)"
    fi

    MENU_ROWS=(
        "󰤨  <b>Wi-Fi Power</b> · $(state_chip "$wifi_state") · <span foreground='${COL_MUTED}'>$(escape_markup "$wifi_detail")</span> · <span foreground='${COL_DIM}'>press Enter to toggle</span>"
        "󰤩  <b>Wi-Fi Networks</b> · <span foreground='${COL_ACTION}'>open network list and connect</span>"
        "  <b>Bluetooth Power</b> · $(state_chip "$bt_state") · <span foreground='${COL_MUTED}'>$(escape_markup "$bt_detail")</span> · <span foreground='${COL_DIM}'>press Enter to toggle</span>"
        "󰂯  <b>Bluetooth Devices</b> · <span foreground='${COL_ACTION}'>connect or disconnect saved devices</span>"
        "󰀝  <b>Airplane Mode</b> · $(state_chip "$airplane_state") · <span foreground='${COL_MUTED}'>$airplane_detail</span>"
        "  <b>Night Light</b> · $(state_chip "$night_state") · <span foreground='${COL_MUTED}'>$night_detail</span>"
        "󰒳  <b>Idle Timeout</b> · $(state_chip "$idle_state") · <span foreground='${COL_MUTED}'>$idle_detail</span>"
        "  <b>Power Profile</b> · <span foreground='${COL_ON}'>$(escape_markup "$power_text")</span> · <span foreground='${COL_DIM}'>press Enter to cycle</span>"
        "󰎆  <b>HyprWave</b> · ${hyprwave_summary}"
        "󰔎  <b>Nucleus Shell Theme</b> · <span foreground='${COL_ACTION}'>switch shell palette</span>"
        "󰡨  <b>Nucleus Extras</b> · <span foreground='${COL_ACTION}'>shell mode, overview, clipboard, screenshot, search, lock</span>"
        "  <b>Open Legacy Hypr Menu</b>"
    )

    rm -rf "$tmpdir"
}

run_main_menu() {
    local choice
    while true; do
        build_main_rows
        choice="$(printf '%s\n' "${MENU_ROWS[@]}" | rofi -dmenu -i -markup-rows -no-custom -config "$ROFI_THEME" -p "Nucleus Controls" -mesg "<span foreground='${COL_PRIMARY}'>Press Enter to run the selected action. Esc closes the menu.</span>" -format i)"
        [[ -z "$choice" ]] && break
        [[ "$choice" =~ ^[0-9]+$ ]] || break

        case "$choice" in
            0) toggle_wifi ;;
            1) wifi_networks_menu ;;
            2) toggle_bluetooth ;;
            3) bluetooth_devices_menu ;;
            4) toggle_airplane_mode ;;
            5) toggle_night_light ;;
            6) toggle_idle_timeout ;;
            7) cycle_power_profile ;;
            8) run_hyprwave_widget ;;
            9) run_nucleus_theme_selector ;;
            10) nucleus_features_menu ;;
            11) [[ -x "$LEGACY_MENU" ]] && "$LEGACY_MENU" ;;
        esac
    done
}

main() {
    if ! have rofi; then
        notify_low "Quick Settings" "rofi is not installed"
        exit 1
    fi

    case "${1:-}" in
        bt-toggle|bluetooth-toggle)
            toggle_bluetooth
            exit 0
            ;;
        bt-on|bluetooth-on)
            if bluetooth_power_on; then
                notify_low "Bluetooth" "Enabled"
                exit 0
            fi
            notify_low "Bluetooth" "Failed to enable (check rfkill/bluetooth.service)"
            exit 1
            ;;
        bt-off|bluetooth-off)
            if bluetooth_power_off; then
                notify_low "Bluetooth" "Disabled"
                exit 0
            fi
            notify_low "Bluetooth" "Failed to disable"
            exit 1
            ;;
        bt-ensure|bluetooth-ensure)
            ensure_bluetooth_stack
            exit 0
            ;;
        wifi)
            wifi_networks_menu
            exit 0
            ;;
        bluetooth)
            bluetooth_devices_menu
            exit 0
            ;;
        hyprwave|music)
            run_hyprwave_widget
            exit 0
            ;;
        nucleus-theme|theme)
            run_nucleus_theme_selector
            exit 0
            ;;
        extras|features)
            nucleus_features_menu
            exit 0
            ;;
        overview)
            run_overview_toggle
            exit 0
            ;;
        overview-shell)
            run_overview_shell
            exit 0
            ;;
        nucleus-shell|nucleus)
            run_overview_shell
            exit 0
            ;;
        clip|clipboard)
            run_clipboard_manager
            exit 0
            ;;
        screenshot|shot)
            run_area_screenshot
            exit 0
            ;;
        search)
            run_rofi_search
            exit 0
            ;;
        lock)
            run_lock_screen
            exit 0
            ;;
        keys|hints)
            run_key_hints
            exit 0
            ;;
        hyprwave-theme)
            run_hyprwave_theme_selector
            exit 0
            ;;
        legacy)
            [[ -x "$LEGACY_MENU" ]] && "$LEGACY_MENU"
            exit 0
            ;;
    esac

    run_main_menu
}

if [[ "${NUCLEUS_QS_LIB_ONLY:-0}" != "1" ]]; then
    main "$@"
fi
