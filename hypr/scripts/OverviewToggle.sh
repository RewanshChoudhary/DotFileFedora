#!/usr/bin/env bash
# /* ----  https://github.com/JaKooLit  ---- */  #
# Overview toggle wrapper - tries Quickshell first, falls back to AGS

set -euo pipefail

START_QUICKSHELL="$HOME/.config/hypr/scripts/StartQuickshell.sh"

# 1) Try Quickshell overview IPC directly first.
if command -v qs >/dev/null 2>&1; then
  if qs ipc -c overview call overview toggle >/dev/null 2>&1; then
    exit 0
  fi
fi

# 2) Ensure overview profile is running, then retry IPC once.
if [[ -x "$START_QUICKSHELL" ]]; then
  "$START_QUICKSHELL" overview >/dev/null 2>&1 || true
elif command -v qs >/dev/null 2>&1; then
  pkill -x quickshell >/dev/null 2>&1 || true
  pkill -x qs >/dev/null 2>&1 || true
  qs -c overview >/dev/null 2>&1 &
fi

sleep 0.6
if command -v qs >/dev/null 2>&1; then
  if qs ipc -c overview call overview toggle >/dev/null 2>&1; then
    exit 0
  fi
fi

# 2) Fall back to AGS template
if command -v ags >/dev/null 2>&1; then
  pkill rofi || true
  if ags -t 'overview' >/dev/null 2>&1; then
    exit 0
  fi
  # If it failed, try starting AGS daemon then call the template
  ags >/dev/null 2>&1 &
  sleep 0.6
  if ags -t 'overview' >/dev/null 2>&1; then
    exit 0
  fi
fi

# If we get here, neither worked
notify-send "Overview" "Neither Quickshell nor AGS is available" -u low 2>/dev/null || true
exit 1
