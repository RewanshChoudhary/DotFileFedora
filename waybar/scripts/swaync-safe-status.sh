#!/usr/bin/env bash
set -uo pipefail

fallback_running='{"text":"","alt":"none","class":"none","tooltip":"Notifications"}'
fallback_down='{"text":"","alt":"none","class":"none","tooltip":"swaync not running"}'

if ! command -v swaync-client >/dev/null 2>&1; then
    printf '%s\n' "$fallback_down"
    exit 0
fi

raw="$(timeout 1500ms swaync-client -swb 2>/dev/null || true)"

if [[ -z "${raw:-}" ]]; then
    if pgrep -x swaync >/dev/null 2>&1; then
        printf '%s\n' "$fallback_running"
    else
        printf '%s\n' "$fallback_down"
    fi
    exit 0
fi

json_line="$(printf '%s\n' "$raw" | awk '/^\{.*\}$/{print; exit}')"

if [[ -n "${json_line:-}" ]]; then
    printf '%s\n' "$json_line"
else
    if pgrep -x swaync >/dev/null 2>&1; then
        printf '%s\n' "$fallback_running"
    else
        printf '%s\n' "$fallback_down"
    fi
fi
