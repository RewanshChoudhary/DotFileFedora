#!/usr/bin/env bash

set -euo pipefail

wifi_state="$(nmcli radio wifi 2>/dev/null || echo disabled)"
wwan_state="$(nmcli radio wwan 2>/dev/null || echo disabled)"

if [ "${wifi_state}" = "enabled" ] || [ "${wwan_state}" = "enabled" ]; then
    nmcli radio all off
    notify-send "Airplane mode" "Enabled"
else
    nmcli radio all on
    notify-send "Airplane mode" "Disabled"
fi
