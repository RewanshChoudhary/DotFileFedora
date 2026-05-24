#!/usr/bin/env bash

set -euo pipefail

confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
icodir="${confDir}/dunst/icons/vol"
default_step=5
volume_limit=1.0

print_error() {
cat <<'EOF'
    ./volumecontrol.sh -[device] <actions>
    ...valid device are...
        i   -- input device
        o   -- output device
        p   -- player application
    ...valid actions are...
        i   -- increase volume [+5]
        d   -- decrease volume [-5]
        m   -- mute [x]
EOF
exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: $1 not found..." >&2
        exit 1
    }
}

describe_pulse_object() {
    local object_type="$1"
    local object_name="$2"

    pactl list "${object_type}" 2>/dev/null | awk -v obj="${object_name}" '
        $1 == "Name:" {
            match_found = ($2 == obj)
            next
        }
        match_found && $1 == "Description:" {
            $1 = ""
            sub(/^ /, "")
            print
            exit
        }
    '
}

get_wpctl_percent() {
    local target="$1"

    wpctl get-volume "${target}" 2>/dev/null | awk '/Volume:/ { printf "%d\n", ($2 * 100) + 0.5 }'
}

is_wpctl_muted() {
    local target="$1"

    wpctl get-volume "${target}" 2>/dev/null | grep -q '\[MUTED\]'
}

notify_vol() {
    local vol="$1"
    local name="$2"
    local angle ico bar

    angle=$(( ((vol + 2) / 5) * 5 ))
    (( angle > 100 )) && angle=100
    ico="${icodir}/vol-${angle}.svg"
    [ -f "${ico}" ] || ico="audio-volume-high"
    bar="$(printf '%*s' $((vol / 15)) '' | tr ' ' '.')"
    notify-send -a "t2" -r 91190 -t 800 -i "${ico}" "${vol}${bar}" "${name}"
}

notify_mute() {
    local muted="$1"
    local device_kind="$2"
    local name="$3"
    local state icon

    if [ "${muted}" = "true" ]; then
        state="muted"
        icon="${icodir}/muted-${device_kind}.svg"
    else
        state="unmuted"
        icon="${icodir}/unmuted-${device_kind}.svg"
    fi

    [ -f "${icon}" ] || icon="audio-volume-muted"
    notify-send -a "t2" -r 91190 -t 800 -i "${icon}" "${state}" "${name}"
}

list_output_sinks() {
    pactl list short sinks 2>/dev/null | awk '{print $2}'
}

move_sink_inputs() {
    local sink_name="$1"

    pactl list short sink-inputs 2>/dev/null | awk '{print $1}' | while read -r input_id; do
        [ -n "${input_id}" ] && pactl move-sink-input "${input_id}" "${sink_name}" >/dev/null 2>&1 || true
    done
}

cycle_output_sink() {
    require_cmd pactl

    local current_sink next_sink
    local -a sinks=()

    while read -r sink_name; do
        [ -n "${sink_name}" ] && sinks+=("${sink_name}")
    done < <(list_output_sinks)

    [ "${#sinks[@]}" -gt 0 ] || {
        echo "ERROR: Output device not found..." >&2
        exit 1
    }

    current_sink="$(pactl get-default-sink 2>/dev/null || true)"
    next_sink="${sinks[0]}"

    for idx in "${!sinks[@]}"; do
        if [ "${sinks[idx]}" = "${current_sink}" ]; then
            next_sink="${sinks[$(((idx + 1) % ${#sinks[@]}))]}"
            break
        fi
    done

    pactl set-default-sink "${next_sink}"
    move_sink_inputs "${next_sink}"
    notify-send -a "t2" -r 91190 -t 1200 "Audio output" "$(describe_pulse_object sinks "${next_sink}")"
}

select_output_sink() {
    require_cmd pactl
    require_cmd rofi

    local current_sink choice sink_name
    local -a entries=()
    local -A label_to_sink=()

    current_sink="$(pactl get-default-sink 2>/dev/null || true)"

    while read -r sink_name; do
        [ -n "${sink_name}" ] || continue
        local desc
        desc="$(describe_pulse_object sinks "${sink_name}")"
        [ -n "${desc}" ] || desc="${sink_name}"
        if [ "${sink_name}" = "${current_sink}" ]; then
            desc="${desc} (default)"
        fi
        entries+=("${desc}")
        label_to_sink["${desc}"]="${sink_name}"
    done < <(list_output_sinks)

    [ "${#entries[@]}" -gt 0 ] || {
        echo "ERROR: Output device not found..." >&2
        exit 1
    }

    choice="$(printf '%s\n' "${entries[@]}" | rofi -dmenu -p 'Output device')"
    [ -n "${choice}" ] || exit 0

    sink_name="${label_to_sink[${choice}]}"
    pactl set-default-sink "${sink_name}"
    move_sink_inputs "${sink_name}"
    notify-send -a "t2" -r 91190 -t 1200 "Audio output" "$(describe_pulse_object sinks "${sink_name}")"
}

device_mode=""
player_name=""
select_sink=0
cycle_sink=0

while getopts ":iop:st" DeviceOpt; do
    case "${DeviceOpt}" in
        i) device_mode="input" ;;
        o) device_mode="output" ;;
        p) device_mode="player"; player_name="${OPTARG}" ;;
        s) select_sink=1 ;;
        t) cycle_sink=1 ;;
        *) print_error ;;
    esac
done

shift $((OPTIND - 1))

if [ "${select_sink}" -eq 1 ]; then
    select_output_sink
    exit 0
fi

if [ "${cycle_sink}" -eq 1 ]; then
    cycle_output_sink
    exit 0
fi

action="${1:-}"
step="${2:-${default_step}}"

case "${device_mode}" in
    input)
        require_cmd wpctl
        require_cmd pactl
        srce="@DEFAULT_AUDIO_SOURCE@"
        nsink="$(pactl get-default-source 2>/dev/null || true)"
        [ -n "${nsink}" ] || {
            echo "ERROR: Input device not found..." >&2
            exit 0
        }
        nsink="$(describe_pulse_object sources "${nsink}")"
        [ -n "${nsink}" ] || nsink="Default microphone"
        device_kind="mic"
        ;;
    output)
        require_cmd wpctl
        require_cmd pactl
        srce="@DEFAULT_AUDIO_SINK@"
        nsink="$(pactl get-default-sink 2>/dev/null || true)"
        [ -n "${nsink}" ] || {
            echo "ERROR: Output device not found..." >&2
            exit 0
        }
        nsink="$(describe_pulse_object sinks "${nsink}")"
        [ -n "${nsink}" ] || nsink="Default speaker"
        device_kind="speaker"
        ;;
    player)
        require_cmd playerctl
        nsink="$(playerctl --list-all 2>/dev/null | grep -x "${player_name}" | head -n 1 || true)"
        [ -n "${nsink}" ] || {
            echo "ERROR: Player ${player_name} not active..." >&2
            exit 0
        }
        srce="${nsink}"
        device_kind="speaker"
        ;;
    *)
        print_error
        ;;
esac

case "${action}" in
    i)
        if [ "${device_mode}" = "player" ]; then
            playerctl --player="${srce}" volume "0.0${step}+"
            vol="$(playerctl --player="${srce}" volume | awk '{ printf "%d\n", ($1 * 100) + 0.5 }')"
        else
            wpctl set-volume -l "${volume_limit}" "${srce}" "${step}%+"
            vol="$(get_wpctl_percent "${srce}")"
        fi
        notify_vol "${vol}" "${nsink}"
        ;;
    d)
        if [ "${device_mode}" = "player" ]; then
            playerctl --player="${srce}" volume "0.0${step}-"
            vol="$(playerctl --player="${srce}" volume | awk '{ printf "%d\n", ($1 * 100) + 0.5 }')"
        else
            wpctl set-volume -l "${volume_limit}" "${srce}" "${step}%-"
            vol="$(get_wpctl_percent "${srce}")"
        fi
        notify_vol "${vol}" "${nsink}"
        ;;
    m)
        if [ "${device_mode}" = "player" ]; then
            if playerctl --player="${srce}" volume | awk '{ exit !($1 > 0) }'; then
                playerctl --player="${srce}" volume 0
                notify_mute true "${device_kind}" "${nsink}"
            else
                playerctl --player="${srce}" volume 1
                notify_mute false "${device_kind}" "${nsink}"
            fi
        else
            wpctl set-mute "${srce}" toggle
            if is_wpctl_muted "${srce}"; then
                notify_mute true "${device_kind}" "${nsink}"
            else
                notify_mute false "${device_kind}" "${nsink}"
            fi
        fi
        ;;
    *)
        print_error
        ;;
esac
