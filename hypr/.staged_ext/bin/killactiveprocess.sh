#!/usr/bin/env bash

set -euo pipefail

pid="$(hyprctl activewindow -j | jq -r '.pid // empty')"
[ -n "${pid}" ] || exit 0

kill -TERM "${pid}" 2>/dev/null || true
sleep 0.2
kill -KILL "${pid}" 2>/dev/null || true
