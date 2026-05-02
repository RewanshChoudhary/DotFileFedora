#!/usr/bin/env bash
set -euo pipefail

PROFILE_STATE_FILE="$HOME/.config/hypr/scripts/.quickshell_profile"
DEFAULT_PROFILE="overview"

have() {
    command -v "$1" >/dev/null 2>&1
}

resolve_launcher() {
    if have qs; then
        printf "qs"
        return 0
    fi
    if have quickshell; then
        printf "quickshell"
        return 0
    fi
    return 1
}

is_valid_profile() {
    case "${1:-}" in
        overview) return 0 ;;
        *) return 1 ;;
    esac
}

profile_running_named() {
    local profile="${1:-}"
    pgrep -af "(^|[ /])(qs|quickshell)([[:space:]].*)?(-c|--config)(=|[[:space:]])${profile}([[:space:]]|$)" >/dev/null 2>&1
}

profile_running_path() {
    local profile="${1:-}"
    pgrep -af "(^|[ /])(qs|quickshell)([[:space:]].*)?(-p|--path)(=|[[:space:]])[^[:space:]]*/quickshell/${profile}(/shell\\.qml)?([[:space:]]|$)" >/dev/null 2>&1
}

profile_running() {
    local profile="${1:-}"
    if ! is_valid_profile "$profile"; then
        return 1
    fi
    profile_running_named "$profile" || profile_running_path "$profile"
}

profile_shell_path() {
    case "${1:-}" in
        overview) printf "%s/.config/quickshell/overview/shell.qml" "$HOME" ;;
        *) return 1 ;;
    esac
}

profile_exists() {
    local profile="${1:-}"
    local shell_path
    shell_path="$(profile_shell_path "$profile")" || return 1
    [[ -f "$shell_path" ]]
}

read_saved_profile() {
    if [[ -f "$PROFILE_STATE_FILE" ]]; then
        local saved
        saved="$(tr -d '[:space:]' <"$PROFILE_STATE_FILE" 2>/dev/null || true)"
        if is_valid_profile "$saved" && profile_exists "$saved"; then
            printf "%s" "$saved"
            return 0
        fi
    fi

    if profile_exists "$DEFAULT_PROFILE"; then
        printf "%s" "$DEFAULT_PROFILE"
    elif profile_exists "overview"; then
        printf "overview"
    else
        printf "%s" "$DEFAULT_PROFILE"
    fi
}

save_profile() {
    local profile="${1:-}"
    mkdir -p "$(dirname "$PROFILE_STATE_FILE")"
    printf "%s\n" "$profile" >"$PROFILE_STATE_FILE"
}

detect_running_profile() {
    if profile_running "overview"; then
        printf "overview"
        return 0
    fi
    if pgrep -x quickshell >/dev/null 2>&1 || pgrep -x qs >/dev/null 2>&1; then
        printf "unknown"
        return 0
    fi
    printf "stopped"
}

stop_quickshell() {
    pkill -x quickshell >/dev/null 2>&1 || true
    pkill -x qs >/dev/null 2>&1 || true
}

start_profile() {
    local profile="${1:-}"
    local launcher

    if ! is_valid_profile "$profile"; then
        echo "Invalid profile: $profile" >&2
        return 1
    fi

    if ! profile_exists "$profile"; then
        echo "Profile shell.qml not found for: $profile" >&2
        return 1
    fi

    launcher="$(resolve_launcher)" || {
        echo "Neither 'qs' nor 'quickshell' is available" >&2
        return 1
    }

    stop_quickshell
    sleep 0.2
    nohup "$launcher" -c "$profile" >"/tmp/quickshell-${profile}.log" 2>&1 &
    disown || true
    sleep 0.4
    if ! profile_running "$profile"; then
        echo "Failed to start quickshell profile: $profile (see /tmp/quickshell-${profile}.log)" >&2
        return 1
    fi
    save_profile "$profile"
}

ensure_running() {
    local current
    current="$(detect_running_profile)"
    if [[ "$current" == "stopped" ]]; then
        start_profile "$(read_saved_profile)"
    fi
}

restart_profile() {
    local profile="${1:-}"
    if [[ -z "$profile" ]]; then
        profile="$(detect_running_profile)"
        if [[ "$profile" == "stopped" || "$profile" == "unknown" ]]; then
            profile="$(read_saved_profile)"
        fi
    fi
    start_profile "$profile"
}

usage() {
    cat <<'EOF'
Usage: StartQuickshell.sh <command> [profile]

Commands:
  ensure                 Start only if quickshell is not running (uses saved/default profile)
  start [profile]        Start quickshell with a profile (default: saved/default)
  restart [profile]      Restart quickshell with current or specified profile
  stop                   Stop quickshell
  status                 Print running profile (overview|unknown|stopped)
  overview               Start quickshell overview profile
  set-default <profile>  Save the default profile to state file
EOF
}

main() {
    local cmd="${1:-ensure}"
    case "$cmd" in
        ensure)
            ensure_running
            ;;
        start|run)
            start_profile "${2:-$(read_saved_profile)}"
            ;;
        restart)
            restart_profile "${2:-}"
            ;;
        stop)
            stop_quickshell
            ;;
        status)
            detect_running_profile
            ;;
        overview)
            start_profile "$cmd"
            ;;
        set-default)
            if ! is_valid_profile "${2:-}"; then
                echo "set-default requires: overview" >&2
                exit 1
            fi
            save_profile "$2"
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
