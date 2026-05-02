#!/usr/bin/env bash
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

ACTION="${1:-toggle}"

have() {
    command -v "$1" >/dev/null 2>&1
}

notify_low() {
    local title="${1:-HyprWave}"
    local body="${2:-}"
    if have notify-send; then
        notify-send -u low "$title" "$body"
    fi
}

hyprwave_running() {
    pgrep -x hyprwave >/dev/null 2>&1
}

start_hyprwave() {
    if ! have hyprwave; then
        notify_low "HyprWave" "hyprwave binary is not installed"
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

hyprwave_send_action() {
    local action="$1"
    if have hyprwave-toggle; then
        hyprwave-toggle "$action" >/dev/null 2>&1 || true
        return 0
    fi

    # Fallback for environments where hyprwave-toggle is missing.
    case "$action" in
        visibility) pkill -SIGUSR1 -x hyprwave >/dev/null 2>&1 || true ;;
        expand) pkill -SIGUSR2 -x hyprwave >/dev/null 2>&1 || true ;;
        play) pkill -SIGRTMIN -x hyprwave >/dev/null 2>&1 || true ;;
        next) pkill -SIGRTMIN+1 -x hyprwave >/dev/null 2>&1 || true ;;
        prev) pkill -SIGRTMIN+2 -x hyprwave >/dev/null 2>&1 || true ;;
    esac
}

show_status_json() {
    if hyprwave_running; then
        printf '{"text":"󰎆","tooltip":"HyprWave is running\\nLeft: show/hide\\nMiddle: play/pause\\nRight: expand","class":"running","alt":"running"}\n'
    else
        printf '{"text":"","tooltip":"HyprWave is stopped\\nLeft: launch widget","class":"stopped","alt":"stopped"}\n'
    fi
}

case "$ACTION" in
    status)
        show_status_json
        ;;
    toggle|visibility)
        if hyprwave_running; then
            hyprwave_send_action "visibility"
        else
            start_hyprwave || exit 1
        fi
        ;;
    expand|play|next|prev)
        if hyprwave_running; then
            hyprwave_send_action "$ACTION"
        else
            start_hyprwave || exit 1
        fi
        ;;
    start)
        start_hyprwave
        ;;
    *)
        notify_low "HyprWave" "Unknown action: $ACTION"
        exit 1
        ;;
esac
