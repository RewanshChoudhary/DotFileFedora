#!/usr/bin/env bash
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

ROFI_THEME="$HOME/.config/rofi/config-nucleus-quicksettings.rasi"
SYNC_ROFI_THEME=1
SWAYNC_STYLE="$HOME/.config/swaync/style.css"
QS_MODULES_APPEARANCE="$HOME/.config/quickshell/modules/common/Appearance.qml"
QS_OVERVIEW_APPEARANCE="$HOME/.config/quickshell/overview/common/Appearance.qml"
QML_COLOR_FILE="$HOME/.config/quickshell/qml_color.json"
THEME_STATE_FILE="$HOME/.config/hypr/scripts/.nucleus_theme.env"
QS_LOG_FILE="/tmp/quickshell-theme-reload.log"
START_QUICKSHELL="$HOME/.config/hypr/scripts/StartQuickshell.sh"
NUCLEUS_CONFIG_DIR="$HOME/.config/nucleus-shell/config"
NUCLEUS_COLORS_FILE="$NUCLEUS_CONFIG_DIR/colors.json"
NUCLEUS_CONFIG_FILE="$NUCLEUS_CONFIG_DIR/configuration.json"
NUCLEUS_COLORSCHEMES_DIR="$HOME/.config/nucleus-shell/colorschemes"

have() {
    command -v "$1" >/dev/null 2>&1
}

notify_low() {
    local title="${1:-Nucleus Theme}"
    local body="${2:-}"
    if have notify-send; then
        notify-send -u low "$title" "$body" >/dev/null 2>&1 || true
    fi
}

set_qml_prop() {
    local file="$1"
    local prop="$2"
    local value="$3"
    perl -0pi -e "s@(property color ${prop}:\\s*\")[^\"]+(\"\\s*)@\\1${value}\\2@g" "$file"
}

set_rasi_var() {
    local file="$1"
    local key="$2"
    local value="$3"
    perl -0pi -e "s@(^\\s*\\Q${key}\\E:\\s*)#[0-9A-Fa-f]{6}(\\s*;)@\\1${value}\\2@mg" "$file"
}

set_css_color() {
    local file="$1"
    local key="$2"
    local value="$3"
    perl -0pi -e "s~(^\\s*\\@define-color\\s+\\Q${key}\\E\\s+)#[0-9A-Fa-f]{6}(\\s*;)~\\1${value}\\2~mg" "$file"
}

set_css_rgba() {
    local file="$1"
    local key="$2"
    local value="$3"
    perl -0pi -e "s~(^\\s*\\@define-color\\s+\\Q${key}\\E\\s+)rgba\\([^\\)]*\\)(\\s*;)~\\1${value}\\2~mg" "$file"
}

restart_swaync() {
    if ! have swaync; then
        return 0
    fi

    if pgrep -x swaync >/dev/null 2>&1; then
        pkill -x swaync >/dev/null 2>&1 || true
        sleep 0.25
    fi

    swaync >/dev/null 2>&1 &
    disown || true

    if have swaync-client; then
        sleep 0.35
        if have timeout; then
            timeout 1 swaync-client --reload-config >/dev/null 2>&1 || true
        else
            swaync-client --reload-config >/dev/null 2>&1 || true
        fi
    fi
}

qs_profile_running_named() {
    local profile="${1:-}"
    pgrep -af "(^|[ /])(qs|quickshell)([[:space:]].*)?(-c|--config)(=|[[:space:]])${profile}([[:space:]]|$)" >/dev/null 2>&1
}

qs_profile_running_path() {
    local profile="${1:-}"
    pgrep -af "(^|[ /])(qs|quickshell)([[:space:]].*)?(-p|--path)(=|[[:space:]])[^[:space:]]*/quickshell/${profile}(/shell\\.qml)?([[:space:]]|$)" >/dev/null 2>&1
}

qs_profile_running() {
    local profile="${1:-}"
    [[ "$profile" == "overview" ]] || return 1
    qs_profile_running_named "$profile" || qs_profile_running_path "$profile"
}

detect_qs_profile() {
    if [[ -x "$START_QUICKSHELL" ]]; then
        local profile
        profile="$("$START_QUICKSHELL" status 2>/dev/null || printf 'stopped')"
        if [[ "$profile" != "unknown" ]]; then
            printf '%s' "$profile"
            return
        fi
    fi

    if qs_profile_running "overview"; then
        printf 'overview'
        return
    fi
    if pgrep -x quickshell >/dev/null 2>&1 || pgrep -x qs >/dev/null 2>&1; then
        printf 'unknown'
        return
    fi
    printf 'stopped'
}

restart_qs_profile() {
    local profile="${1:-}"

    if [[ -x "$START_QUICKSHELL" ]]; then
        if [[ "$profile" == "overview" ]]; then
            "$START_QUICKSHELL" restart "$profile" >/dev/null 2>&1
        else
            "$START_QUICKSHELL" restart >/dev/null 2>&1
        fi
        return $?
    fi

    if ! have qs; then
        return 1
    fi

    if [[ "$profile" != "overview" ]]; then
        profile="overview"
    fi

    pkill -x quickshell >/dev/null 2>&1 || true
    pkill -x qs >/dev/null 2>&1 || true
    sleep 0.25
    nohup qs -c "$profile" >"$QS_LOG_FILE" 2>&1 &
    disown || true
}

attempt_restart_qs_profile() {
    local profile="${1:-}"
    [[ -n "$profile" ]] || return 1

    if ! restart_qs_profile "$profile"; then
        return 1
    fi

    local after
    after="$(detect_qs_profile)"
    [[ "$after" == "stopped" ]] && return 1
    if [[ "$after" == "unknown" ]]; then
        printf '%s' "$profile"
    else
        printf '%s' "$after"
    fi
}

restart_qs_with_fallback() {
    local requested="${1:-unknown}"
    local result=""

    result="$(attempt_restart_qs_profile "$requested")" && {
        printf '%s' "$result"
        return 0
    }

    if [[ "$requested" != "overview" ]]; then
        result="$(attempt_restart_qs_profile "overview")" && {
            printf '%s' "$result"
            return 0
        }
    fi

    return 1
}

apply_palette() {
    local theme_key="$1"
    [[ "$theme_key" == "rosepine" ]] && theme_key="rose-pine"

    local m3windowBackground m3primaryText m3layerBackground1 m3layerBackground2 m3layerBackground3
    local m3surfaceText m3secondaryText m3borderPrimary m3shadowColor m3accentPrimary m3accentSecondary
    local m3selectionBackground m3accentPrimaryText m3selectionText m3borderSecondary colTooltip colOnTooltip

    local m3primary m3onPrimary m3primaryContainer m3onPrimaryContainer m3secondary m3onSecondary
    local m3secondaryContainer m3onSecondaryContainer m3background m3onBackground m3surface
    local m3surfaceContainerLow m3surfaceContainer m3surfaceContainerHigh m3surfaceContainerHighest
    local m3onSurface m3surfaceVariant m3onSurfaceVariant m3inverseSurface m3inverseOnSurface
    local m3outline m3outlineVariant m3shadow
    local rofi_bg rofi_bg_alt rofi_card rofi_card_active rofi_fg rofi_muted rofi_border
    local rofi_selected_bg rofi_selected_fg rofi_prompt
    local col_text col_muted col_primary col_on col_off col_secure col_open col_dim col_action

    case "$theme_key" in
        orchid)
            m3windowBackground="#161217"
            m3primaryText="#EAE0E7"
            m3layerBackground1="#1F1A1F"
            m3layerBackground2="#231E23"
            m3layerBackground3="#2D282E"
            m3surfaceText="#EAE0E7"
            m3secondaryText="#CFC3CD"
            m3borderPrimary="#E5B6F2"
            m3shadowColor="#000000"
            m3accentPrimary="#E5B6F2"
            m3accentSecondary="#D5C0D7"
            m3selectionBackground="#534457"
            m3accentPrimaryText="#452152"
            m3selectionText="#F2DCF3"
            m3borderSecondary="#4C444D"
            colTooltip="#1E1E2E"
            colOnTooltip="#F8F9FA"

            m3primary="#E5B6F2"
            m3onPrimary="#452152"
            m3primaryContainer="#5D386A"
            m3onPrimaryContainer="#F9D8FF"
            m3secondary="#D5C0D7"
            m3onSecondary="#392C3D"
            m3secondaryContainer="#534457"
            m3onSecondaryContainer="#F2DCF3"
            m3background="#161217"
            m3onBackground="#EAE0E7"
            m3surface="#161217"
            m3surfaceContainerLow="#1F1A1F"
            m3surfaceContainer="#231E23"
            m3surfaceContainerHigh="#2D282E"
            m3surfaceContainerHighest="#383339"
            m3onSurface="#EAE0E7"
            m3surfaceVariant="#4C444D"
            m3onSurfaceVariant="#CFC3CD"
            m3inverseSurface="#EAE0E7"
            m3inverseOnSurface="#342F34"
            m3outline="#988E97"
            m3outlineVariant="#4C444D"
            m3shadow="#000000"

            rofi_bg="#161217"
            rofi_bg_alt="#1F1A1F"
            rofi_card="#231E23"
            rofi_card_active="#2D282E"
            rofi_fg="#EAE0E7"
            rofi_muted="#CFC3CD"
            rofi_border="#4C444D"
            rofi_selected_bg="#5D386A"
            rofi_selected_fg="#F9D8FF"
            rofi_prompt="#E5B6F2"

            col_text="#EAE0E7"
            col_muted="#CFC3CD"
            col_primary="#E5B6F2"
            col_on="#F9D8FF"
            col_off="#FFB4AB"
            col_secure="#F2DCF3"
            col_open="#CFC3CD"
            col_dim="#988E97"
            col_action="#D5C0D7"
            ;;
        emerald)
            m3windowBackground="#0F1511"
            m3primaryText="#E6EFE8"
            m3layerBackground1="#16201A"
            m3layerBackground2="#1D2A22"
            m3layerBackground3="#25362B"
            m3surfaceText="#E6EFE8"
            m3secondaryText="#C5D0C8"
            m3borderPrimary="#8BD5A1"
            m3shadowColor="#000000"
            m3accentPrimary="#8BD5A1"
            m3accentSecondary="#A8D8B4"
            m3selectionBackground="#2F4D3C"
            m3accentPrimaryText="#0E3A1D"
            m3selectionText="#D4EEDF"
            m3borderSecondary="#425449"
            colTooltip="#15251C"
            colOnTooltip="#EAF7EE"

            m3primary="#8BD5A1"
            m3onPrimary="#0E3A1D"
            m3primaryContainer="#1F5A33"
            m3onPrimaryContainer="#C8F6D4"
            m3secondary="#A8D8B4"
            m3onSecondary="#1E3A29"
            m3secondaryContainer="#2F4D3C"
            m3onSecondaryContainer="#D4EEDF"
            m3background="#0F1511"
            m3onBackground="#E6EFE8"
            m3surface="#0F1511"
            m3surfaceContainerLow="#16201A"
            m3surfaceContainer="#1D2A22"
            m3surfaceContainerHigh="#25362B"
            m3surfaceContainerHighest="#2E4336"
            m3onSurface="#E6EFE8"
            m3surfaceVariant="#425449"
            m3onSurfaceVariant="#C5D0C8"
            m3inverseSurface="#E6EFE8"
            m3inverseOnSurface="#233026"
            m3outline="#8E9E93"
            m3outlineVariant="#425449"
            m3shadow="#000000"

            rofi_bg="#0F1511"
            rofi_bg_alt="#16201A"
            rofi_card="#1D2A22"
            rofi_card_active="#25362B"
            rofi_fg="#E6EFE8"
            rofi_muted="#C5D0C8"
            rofi_border="#425449"
            rofi_selected_bg="#1F5A33"
            rofi_selected_fg="#C8F6D4"
            rofi_prompt="#8BD5A1"

            col_text="#E6EFE8"
            col_muted="#C5D0C8"
            col_primary="#8BD5A1"
            col_on="#C8F6D4"
            col_off="#FFB4AB"
            col_secure="#D4EEDF"
            col_open="#C5D0C8"
            col_dim="#8E9E93"
            col_action="#A8D8B4"
            ;;
        amber)
            m3windowBackground="#16130F"
            m3primaryText="#EEE3D5"
            m3layerBackground1="#1F1A14"
            m3layerBackground2="#2A231B"
            m3layerBackground3="#362E24"
            m3surfaceText="#EEE3D5"
            m3secondaryText="#D5C8B7"
            m3borderPrimary="#D7B46A"
            m3shadowColor="#000000"
            m3accentPrimary="#D7B46A"
            m3accentSecondary="#D5C0A3"
            m3selectionBackground="#53442F"
            m3accentPrimaryText="#3F2B04"
            m3selectionText="#F2DFC2"
            m3borderSecondary="#5A4A35"
            colTooltip="#2A2218"
            colOnTooltip="#F7EAD6"

            m3primary="#D7B46A"
            m3onPrimary="#3F2B04"
            m3primaryContainer="#6B4D14"
            m3onPrimaryContainer="#FFDFA3"
            m3secondary="#D5C0A3"
            m3onSecondary="#3A2F1B"
            m3secondaryContainer="#53442F"
            m3onSecondaryContainer="#F2DFC2"
            m3background="#16130F"
            m3onBackground="#EEE3D5"
            m3surface="#16130F"
            m3surfaceContainerLow="#1F1A14"
            m3surfaceContainer="#2A231B"
            m3surfaceContainerHigh="#362E24"
            m3surfaceContainerHighest="#41372B"
            m3onSurface="#EEE3D5"
            m3surfaceVariant="#5A4A35"
            m3onSurfaceVariant="#D5C8B7"
            m3inverseSurface="#EEE3D5"
            m3inverseOnSurface="#342A1E"
            m3outline="#A0917D"
            m3outlineVariant="#5A4A35"
            m3shadow="#000000"

            rofi_bg="#16130F"
            rofi_bg_alt="#1F1A14"
            rofi_card="#2A231B"
            rofi_card_active="#362E24"
            rofi_fg="#EEE3D5"
            rofi_muted="#D5C8B7"
            rofi_border="#5A4A35"
            rofi_selected_bg="#6B4D14"
            rofi_selected_fg="#FFDFA3"
            rofi_prompt="#D7B46A"

            col_text="#EEE3D5"
            col_muted="#D5C8B7"
            col_primary="#D7B46A"
            col_on="#FFDFA3"
            col_off="#FFB4AB"
            col_secure="#F2DFC2"
            col_open="#D5C8B7"
            col_dim="#A0917D"
            col_action="#D5C0A3"
            ;;
        persona3-reload)
            m3windowBackground="#0A0F2E"
            m3primaryText="#E8EEF8"
            m3layerBackground1="#0D1438"
            m3layerBackground2="#10255C"
            m3layerBackground3="#173A77"
            m3surfaceText="#E8EEF8"
            m3secondaryText="#AEBBD7"
            m3borderPrimary="#00C8FF"
            m3shadowColor="#000000"
            m3accentPrimary="#00C8FF"
            m3accentSecondary="#1E4FA8"
            m3selectionBackground="#3A4A6B"
            m3accentPrimaryText="#07142E"
            m3selectionText="#E8EEF8"
            m3borderSecondary="#243458"
            colTooltip="#121A42"
            colOnTooltip="#E8EEF8"

            m3primary="#00C8FF"
            m3onPrimary="#07142E"
            m3primaryContainer="#10255C"
            m3onPrimaryContainer="#E8EEF8"
            m3secondary="#1E4FA8"
            m3onSecondary="#E8EEF8"
            m3secondaryContainer="#173A77"
            m3onSecondaryContainer="#DDE7FF"
            m3background="#0A0F2E"
            m3onBackground="#E8EEF8"
            m3surface="#0A0F2E"
            m3surfaceContainerLow="#0D1438"
            m3surfaceContainer="#10255C"
            m3surfaceContainerHigh="#173A77"
            m3surfaceContainerHighest="#1E4FA8"
            m3onSurface="#E8EEF8"
            m3surfaceVariant="#3A4A6B"
            m3onSurfaceVariant="#AEBBD7"
            m3inverseSurface="#E8EEF8"
            m3inverseOnSurface="#0A0F2E"
            m3outline="#5B6F96"
            m3outlineVariant="#243458"
            m3shadow="#000000"

            rofi_bg="#0A0F2E"
            rofi_bg_alt="#0D1438"
            rofi_card="#10255C"
            rofi_card_active="#173A77"
            rofi_fg="#E8EEF8"
            rofi_muted="#AEBBD7"
            rofi_border="#243458"
            rofi_selected_bg="#1E4FA8"
            rofi_selected_fg="#E8EEF8"
            rofi_prompt="#00C8FF"

            col_text="#E8EEF8"
            col_muted="#AEBBD7"
            col_primary="#00C8FF"
            col_on="#E8EEF8"
            col_off="#C0141E"
            col_secure="#00C8FF"
            col_open="#1E4FA8"
            col_dim="#5B6F96"
            col_action="#1E4FA8"
            ;;
        persona4-golden)
            m3windowBackground="#2A2420"
            m3primaryText="#FAF0DC"
            m3layerBackground1="#312B25"
            m3layerBackground2="#3A312B"
            m3layerBackground3="#4A3D32"
            m3surfaceText="#FAF0DC"
            m3secondaryText="#C9BFAE"
            m3borderPrimary="#F5C500"
            m3shadowColor="#000000"
            m3accentPrimary="#F5C500"
            m3accentSecondary="#4A8C3C"
            m3selectionBackground="#5A4A33"
            m3accentPrimaryText="#2A2420"
            m3selectionText="#FAF0DC"
            m3borderSecondary="#6B5A47"
            colTooltip="#3A312B"
            colOnTooltip="#FAF0DC"

            m3primary="#F5C500"
            m3onPrimary="#2A2420"
            m3primaryContainer="#E08C00"
            m3onPrimaryContainer="#FFF2C6"
            m3secondary="#4A8C3C"
            m3onSecondary="#FAF0DC"
            m3secondaryContainer="#355E2D"
            m3onSecondaryContainer="#D7F3CC"
            m3background="#2A2420"
            m3onBackground="#FAF0DC"
            m3surface="#2A2420"
            m3surfaceContainerLow="#312B25"
            m3surfaceContainer="#3A312B"
            m3surfaceContainerHigh="#4A3D32"
            m3surfaceContainerHighest="#5A4A3E"
            m3onSurface="#FAF0DC"
            m3surfaceVariant="#6B5A47"
            m3onSurfaceVariant="#C9BFAE"
            m3inverseSurface="#FAF0DC"
            m3inverseOnSurface="#2A2420"
            m3outline="#A89782"
            m3outlineVariant="#6B5A47"
            m3shadow="#000000"

            rofi_bg="#2A2420"
            rofi_bg_alt="#312B25"
            rofi_card="#3A312B"
            rofi_card_active="#4A3D32"
            rofi_fg="#FAF0DC"
            rofi_muted="#C9BFAE"
            rofi_border="#6B5A47"
            rofi_selected_bg="#E08C00"
            rofi_selected_fg="#FFF2C6"
            rofi_prompt="#F5C500"

            col_text="#FAF0DC"
            col_muted="#C9BFAE"
            col_primary="#F5C500"
            col_on="#FFF2C6"
            col_off="#F07830"
            col_secure="#4A8C3C"
            col_open="#E08C00"
            col_dim="#A89782"
            col_action="#4A8C3C"
            ;;
        persona5-royal)
            m3windowBackground="#0D0D0D"
            m3primaryText="#F0F0F0"
            m3layerBackground1="#151515"
            m3layerBackground2="#1F1F1F"
            m3layerBackground3="#2A2A2A"
            m3surfaceText="#F0F0F0"
            m3secondaryText="#C9C9C9"
            m3borderPrimary="#E01020"
            m3shadowColor="#000000"
            m3accentPrimary="#E01020"
            m3accentSecondary="#D4A017"
            m3selectionBackground="#2A2A2A"
            m3accentPrimaryText="#F0F0F0"
            m3selectionText="#F0F0F0"
            m3borderSecondary="#3A3A3A"
            colTooltip="#1A1A1A"
            colOnTooltip="#F0F0F0"

            m3primary="#E01020"
            m3onPrimary="#F0F0F0"
            m3primaryContainer="#8B0000"
            m3onPrimaryContainer="#FFE1E4"
            m3secondary="#2050A0"
            m3onSecondary="#F0F0F0"
            m3secondaryContainer="#1A2F5B"
            m3onSecondaryContainer="#DDE7FF"
            m3background="#0D0D0D"
            m3onBackground="#F0F0F0"
            m3surface="#0D0D0D"
            m3surfaceContainerLow="#151515"
            m3surfaceContainer="#1F1F1F"
            m3surfaceContainerHigh="#2A2A2A"
            m3surfaceContainerHighest="#363636"
            m3onSurface="#F0F0F0"
            m3surfaceVariant="#3A3A3A"
            m3onSurfaceVariant="#C9C9C9"
            m3inverseSurface="#F0F0F0"
            m3inverseOnSurface="#0D0D0D"
            m3outline="#7A7A7A"
            m3outlineVariant="#3A3A3A"
            m3shadow="#000000"

            rofi_bg="#0D0D0D"
            rofi_bg_alt="#151515"
            rofi_card="#1F1F1F"
            rofi_card_active="#2A2A2A"
            rofi_fg="#F0F0F0"
            rofi_muted="#C9C9C9"
            rofi_border="#3A3A3A"
            rofi_selected_bg="#8B0000"
            rofi_selected_fg="#FFE1E4"
            rofi_prompt="#E01020"

            col_text="#F0F0F0"
            col_muted="#C9C9C9"
            col_primary="#E01020"
            col_on="#FFE1E4"
            col_off="#E01020"
            col_secure="#D4A017"
            col_open="#2050A0"
            col_dim="#7A7A7A"
            col_action="#D4A017"
            ;;
        gruvbox)
            m3windowBackground="#282828"
            m3primaryText="#EBDBB2"
            m3layerBackground1="#32302F"
            m3layerBackground2="#3C3836"
            m3layerBackground3="#504945"
            m3surfaceText="#EBDBB2"
            m3secondaryText="#D5C4A1"
            m3borderPrimary="#D79921"
            m3shadowColor="#1D2021"
            m3accentPrimary="#D79921"
            m3accentSecondary="#83A598"
            m3selectionBackground="#665C54"
            m3accentPrimaryText="#282828"
            m3selectionText="#FBF1C7"
            m3borderSecondary="#665C54"
            colTooltip="#1D2021"
            colOnTooltip="#FBF1C7"

            m3primary="#D79921"
            m3onPrimary="#282828"
            m3primaryContainer="#B57614"
            m3onPrimaryContainer="#FBF1C7"
            m3secondary="#83A598"
            m3onSecondary="#1D2021"
            m3secondaryContainer="#3C3836"
            m3onSecondaryContainer="#D5C4A1"
            m3background="#282828"
            m3onBackground="#EBDBB2"
            m3surface="#282828"
            m3surfaceContainerLow="#32302F"
            m3surfaceContainer="#3C3836"
            m3surfaceContainerHigh="#504945"
            m3surfaceContainerHighest="#665C54"
            m3onSurface="#EBDBB2"
            m3surfaceVariant="#665C54"
            m3onSurfaceVariant="#D5C4A1"
            m3inverseSurface="#EBDBB2"
            m3inverseOnSurface="#282828"
            m3outline="#A89984"
            m3outlineVariant="#665C54"
            m3shadow="#1D2021"

            rofi_bg="#282828"
            rofi_bg_alt="#32302F"
            rofi_card="#3C3836"
            rofi_card_active="#504945"
            rofi_fg="#EBDBB2"
            rofi_muted="#D5C4A1"
            rofi_border="#665C54"
            rofi_selected_bg="#B57614"
            rofi_selected_fg="#FBF1C7"
            rofi_prompt="#D79921"

            col_text="#EBDBB2"
            col_muted="#D5C4A1"
            col_primary="#D79921"
            col_on="#FBF1C7"
            col_off="#FB4934"
            col_secure="#B8BB26"
            col_open="#83A598"
            col_dim="#A89984"
            col_action="#8EC07C"
            ;;
        catppuccin)
            m3windowBackground="#1E1E2E"
            m3primaryText="#CDD6F4"
            m3layerBackground1="#181825"
            m3layerBackground2="#1E1E2E"
            m3layerBackground3="#313244"
            m3surfaceText="#CDD6F4"
            m3secondaryText="#A6ADC8"
            m3borderPrimary="#B4BEFE"
            m3shadowColor="#11111B"
            m3accentPrimary="#B4BEFE"
            m3accentSecondary="#F5BDE6"
            m3selectionBackground="#45475A"
            m3accentPrimaryText="#11111B"
            m3selectionText="#CDD6F4"
            m3borderSecondary="#585B70"
            colTooltip="#11111B"
            colOnTooltip="#CDD6F4"

            m3primary="#B4BEFE"
            m3onPrimary="#11111B"
            m3primaryContainer="#313244"
            m3onPrimaryContainer="#CDD6F4"
            m3secondary="#F5BDE6"
            m3onSecondary="#11111B"
            m3secondaryContainer="#3A2A3D"
            m3onSecondaryContainer="#F7D8EF"
            m3background="#1E1E2E"
            m3onBackground="#CDD6F4"
            m3surface="#1E1E2E"
            m3surfaceContainerLow="#181825"
            m3surfaceContainer="#1E1E2E"
            m3surfaceContainerHigh="#313244"
            m3surfaceContainerHighest="#45475A"
            m3onSurface="#CDD6F4"
            m3surfaceVariant="#585B70"
            m3onSurfaceVariant="#A6ADC8"
            m3inverseSurface="#CDD6F4"
            m3inverseOnSurface="#1E1E2E"
            m3outline="#7F849C"
            m3outlineVariant="#45475A"
            m3shadow="#11111B"

            rofi_bg="#1E1E2E"
            rofi_bg_alt="#181825"
            rofi_card="#1E1E2E"
            rofi_card_active="#313244"
            rofi_fg="#CDD6F4"
            rofi_muted="#A6ADC8"
            rofi_border="#585B70"
            rofi_selected_bg="#313244"
            rofi_selected_fg="#CDD6F4"
            rofi_prompt="#B4BEFE"

            col_text="#CDD6F4"
            col_muted="#A6ADC8"
            col_primary="#B4BEFE"
            col_on="#CDD6F4"
            col_off="#F38BA8"
            col_secure="#F7D8EF"
            col_open="#A6ADC8"
            col_dim="#7F849C"
            col_action="#F5BDE6"
            ;;
        mystic-portal)
            m3windowBackground="#0F0C1E"
            m3primaryText="#FFDCF5"
            m3layerBackground1="#141228"
            m3layerBackground2="#191630"
            m3layerBackground3="#251E3C"
            m3surfaceText="#FFDCF5"
            m3secondaryText="#E6BEDC"
            m3borderPrimary="#8C64B4"
            m3shadowColor="#000000"
            m3accentPrimary="#FF64C8"
            m3accentSecondary="#783CC8"
            m3selectionBackground="#30264B"
            m3accentPrimaryText="#0F0C1E"
            m3selectionText="#FFDCF5"
            m3borderSecondary="#64468C"
            colTooltip="#141228"
            colOnTooltip="#FFDCF5"

            m3primary="#FF64C8"
            m3onPrimary="#0F0C1E"
            m3primaryContainer="#4A224D"
            m3onPrimaryContainer="#FFDCF5"
            m3secondary="#8C64B4"
            m3onSecondary="#0F0C1E"
            m3secondaryContainer="#2E2344"
            m3onSecondaryContainer="#F5D8FF"
            m3background="#0F0C1E"
            m3onBackground="#FFDCF5"
            m3surface="#141228"
            m3surfaceContainerLow="#141228"
            m3surfaceContainer="#191630"
            m3surfaceContainerHigh="#251E3C"
            m3surfaceContainerHighest="#30264B"
            m3onSurface="#FFDCF5"
            m3surfaceVariant="#57406E"
            m3onSurfaceVariant="#D9B7D4"
            m3inverseSurface="#FFDCF5"
            m3inverseOnSurface="#0F0C1E"
            m3outline="#A078B2"
            m3outlineVariant="#64468C"
            m3shadow="#000000"

            rofi_bg="#0F0C1E"
            rofi_bg_alt="#141228"
            rofi_card="#191630"
            rofi_card_active="#251E3C"
            rofi_fg="#FFDCF5"
            rofi_muted="#C8A0C3"
            rofi_border="#64468C"
            rofi_selected_bg="#30264B"
            rofi_selected_fg="#FFDCF5"
            rofi_prompt="#FF64C8"

            col_text="#FFDCF5"
            col_muted="#C8A0C3"
            col_primary="#FF64C8"
            col_on="#FFDCF5"
            col_off="#E646AA"
            col_secure="#D8B4FF"
            col_open="#E6BEDC"
            col_dim="#A078A5"
            col_action="#783CC8"
            ;;
        tokyonight)
            m3windowBackground="#1A1B26"
            m3primaryText="#C0CAF5"
            m3layerBackground1="#1F2335"
            m3layerBackground2="#24283B"
            m3layerBackground3="#2A2F46"
            m3surfaceText="#C0CAF5"
            m3secondaryText="#A9B1D6"
            m3borderPrimary="#7AA2F7"
            m3shadowColor="#000000"
            m3accentPrimary="#7AA2F7"
            m3accentSecondary="#BB9AF7"
            m3selectionBackground="#414868"
            m3accentPrimaryText="#1A1B26"
            m3selectionText="#C0CAF5"
            m3borderSecondary="#565F89"
            colTooltip="#1F2335"
            colOnTooltip="#C0CAF5"

            m3primary="#7AA2F7"
            m3onPrimary="#1A1B26"
            m3primaryContainer="#3D59A1"
            m3onPrimaryContainer="#C0CAF5"
            m3secondary="#BB9AF7"
            m3onSecondary="#1A1B26"
            m3secondaryContainer="#414868"
            m3onSecondaryContainer="#C0CAF5"
            m3background="#1A1B26"
            m3onBackground="#C0CAF5"
            m3surface="#1A1B26"
            m3surfaceContainerLow="#1F2335"
            m3surfaceContainer="#24283B"
            m3surfaceContainerHigh="#2A2F46"
            m3surfaceContainerHighest="#414868"
            m3onSurface="#C0CAF5"
            m3surfaceVariant="#565F89"
            m3onSurfaceVariant="#A9B1D6"
            m3inverseSurface="#C0CAF5"
            m3inverseOnSurface="#1A1B26"
            m3outline="#737AA2"
            m3outlineVariant="#565F89"
            m3shadow="#000000"

            rofi_bg="#1A1B26"
            rofi_bg_alt="#1F2335"
            rofi_card="#24283B"
            rofi_card_active="#2A2F46"
            rofi_fg="#C0CAF5"
            rofi_muted="#A9B1D6"
            rofi_border="#565F89"
            rofi_selected_bg="#3D59A1"
            rofi_selected_fg="#C0CAF5"
            rofi_prompt="#7AA2F7"

            col_text="#C0CAF5"
            col_muted="#A9B1D6"
            col_primary="#7AA2F7"
            col_on="#C0CAF5"
            col_off="#F7768E"
            col_secure="#9ECE6A"
            col_open="#7DCFFF"
            col_dim="#737AA2"
            col_action="#BB9AF7"
            ;;
        kanagawa)
            m3windowBackground="#1F1F28"
            m3primaryText="#DCD7BA"
            m3layerBackground1="#2A2A37"
            m3layerBackground2="#2D2D3B"
            m3layerBackground3="#363646"
            m3surfaceText="#DCD7BA"
            m3secondaryText="#C8C093"
            m3borderPrimary="#7E9CD8"
            m3shadowColor="#000000"
            m3accentPrimary="#7E9CD8"
            m3accentSecondary="#957FB8"
            m3selectionBackground="#363646"
            m3accentPrimaryText="#1F1F28"
            m3selectionText="#DCD7BA"
            m3borderSecondary="#54546D"
            colTooltip="#2A2A37"
            colOnTooltip="#DCD7BA"

            m3primary="#7E9CD8"
            m3onPrimary="#1F1F28"
            m3primaryContainer="#2A2A37"
            m3onPrimaryContainer="#DCD7BA"
            m3secondary="#957FB8"
            m3onSecondary="#1F1F28"
            m3secondaryContainer="#363646"
            m3onSecondaryContainer="#DCD7BA"
            m3background="#1F1F28"
            m3onBackground="#DCD7BA"
            m3surface="#1F1F28"
            m3surfaceContainerLow="#2A2A37"
            m3surfaceContainer="#2D2D3B"
            m3surfaceContainerHigh="#363646"
            m3surfaceContainerHighest="#54546D"
            m3onSurface="#DCD7BA"
            m3surfaceVariant="#54546D"
            m3onSurfaceVariant="#C8C093"
            m3inverseSurface="#DCD7BA"
            m3inverseOnSurface="#1F1F28"
            m3outline="#727169"
            m3outlineVariant="#54546D"
            m3shadow="#000000"

            rofi_bg="#1F1F28"
            rofi_bg_alt="#2A2A37"
            rofi_card="#2D2D3B"
            rofi_card_active="#363646"
            rofi_fg="#DCD7BA"
            rofi_muted="#C8C093"
            rofi_border="#54546D"
            rofi_selected_bg="#2A2A37"
            rofi_selected_fg="#DCD7BA"
            rofi_prompt="#7E9CD8"

            col_text="#DCD7BA"
            col_muted="#C8C093"
            col_primary="#7E9CD8"
            col_on="#DCD7BA"
            col_off="#E46876"
            col_secure="#98BB6C"
            col_open="#7FB4CA"
            col_dim="#727169"
            col_action="#957FB8"
            ;;
        rose-pine)
            m3windowBackground="#191724"
            m3primaryText="#E0DEF4"
            m3layerBackground1="#1F1D2E"
            m3layerBackground2="#26233A"
            m3layerBackground3="#312E45"
            m3surfaceText="#E0DEF4"
            m3secondaryText="#908CAA"
            m3borderPrimary="#C4A7E7"
            m3shadowColor="#000000"
            m3accentPrimary="#C4A7E7"
            m3accentSecondary="#9CCFD8"
            m3selectionBackground="#403D52"
            m3accentPrimaryText="#191724"
            m3selectionText="#E0DEF4"
            m3borderSecondary="#6E6A86"
            colTooltip="#1F1D2E"
            colOnTooltip="#E0DEF4"

            m3primary="#C4A7E7"
            m3onPrimary="#191724"
            m3primaryContainer="#403D52"
            m3onPrimaryContainer="#E0DEF4"
            m3secondary="#9CCFD8"
            m3onSecondary="#191724"
            m3secondaryContainer="#26233A"
            m3onSecondaryContainer="#E0DEF4"
            m3background="#191724"
            m3onBackground="#E0DEF4"
            m3surface="#191724"
            m3surfaceContainerLow="#1F1D2E"
            m3surfaceContainer="#26233A"
            m3surfaceContainerHigh="#312E45"
            m3surfaceContainerHighest="#403D52"
            m3onSurface="#E0DEF4"
            m3surfaceVariant="#6E6A86"
            m3onSurfaceVariant="#908CAA"
            m3inverseSurface="#E0DEF4"
            m3inverseOnSurface="#191724"
            m3outline="#908CAA"
            m3outlineVariant="#6E6A86"
            m3shadow="#000000"

            rofi_bg="#191724"
            rofi_bg_alt="#1F1D2E"
            rofi_card="#26233A"
            rofi_card_active="#312E45"
            rofi_fg="#E0DEF4"
            rofi_muted="#908CAA"
            rofi_border="#6E6A86"
            rofi_selected_bg="#403D52"
            rofi_selected_fg="#E0DEF4"
            rofi_prompt="#C4A7E7"

            col_text="#E0DEF4"
            col_muted="#908CAA"
            col_primary="#C4A7E7"
            col_on="#E0DEF4"
            col_off="#EB6F92"
            col_secure="#9CCFD8"
            col_open="#9CCFD8"
            col_dim="#6E6A86"
            col_action="#F6C177"
            ;;
        *)
            notify_low "Nucleus Theme" "Unknown theme: $theme_key"
            return 1
            ;;
    esac

    if [[ ! -f "$QS_MODULES_APPEARANCE" || ! -f "$QS_OVERVIEW_APPEARANCE" ]]; then
        notify_low "Nucleus Theme" "Quickshell Appearance files not found"
        return 1
    fi

    # modules/common/Appearance.qml colors
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3windowBackground" "$m3windowBackground"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3primaryText" "$m3primaryText"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3layerBackground1" "$m3layerBackground1"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3layerBackground2" "$m3layerBackground2"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3layerBackground3" "$m3layerBackground3"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3surfaceText" "$m3surfaceText"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3secondaryText" "$m3secondaryText"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3borderPrimary" "$m3borderPrimary"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3shadowColor" "$m3shadowColor"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3accentPrimary" "$m3accentPrimary"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3accentSecondary" "$m3accentSecondary"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3selectionBackground" "$m3selectionBackground"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3accentPrimaryText" "$m3accentPrimaryText"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3selectionText" "$m3selectionText"
    set_qml_prop "$QS_MODULES_APPEARANCE" "m3borderSecondary" "$m3borderSecondary"
    set_qml_prop "$QS_MODULES_APPEARANCE" "colTooltip" "$colTooltip"
    set_qml_prop "$QS_MODULES_APPEARANCE" "colOnTooltip" "$colOnTooltip"

    # overview/common/Appearance.qml colors
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3primary" "$m3primary"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3onPrimary" "$m3onPrimary"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3primaryContainer" "$m3primaryContainer"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3onPrimaryContainer" "$m3onPrimaryContainer"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3secondary" "$m3secondary"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3onSecondary" "$m3onSecondary"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3secondaryContainer" "$m3secondaryContainer"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3onSecondaryContainer" "$m3onSecondaryContainer"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3background" "$m3background"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3onBackground" "$m3onBackground"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3surface" "$m3surface"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3surfaceContainerLow" "$m3surfaceContainerLow"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3surfaceContainer" "$m3surfaceContainer"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3surfaceContainerHigh" "$m3surfaceContainerHigh"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3surfaceContainerHighest" "$m3surfaceContainerHighest"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3onSurface" "$m3onSurface"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3surfaceVariant" "$m3surfaceVariant"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3onSurfaceVariant" "$m3onSurfaceVariant"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3inverseSurface" "$m3inverseSurface"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3inverseOnSurface" "$m3inverseOnSurface"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3outline" "$m3outline"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3outlineVariant" "$m3outlineVariant"
    set_qml_prop "$QS_OVERVIEW_APPEARANCE" "m3shadow" "$m3shadow"

    # Keep qml_color.json coherent for services relying on it.
    cat >"$QML_COLOR_FILE" <<EOF
{
    "windowBackground": "$m3windowBackground",
    "primaryText": "$m3primaryText",
    "layerBackground1": "$m3layerBackground1",
    "layerBackground2": "$m3layerBackground2",
    "layerBackground3": "$m3layerBackground3",
    "surfaceText": "$m3surfaceText",
    "secondaryText": "$m3secondaryText",
    "borderPrimary": "$m3borderPrimary",
    "shadowColor": "$m3shadowColor",
    "accentPrimary": "$m3accentPrimary",
    "accentSecondary": "$m3accentSecondary",
    "selectionBackground": "$m3selectionBackground",
    "accentPrimaryText": "$m3accentPrimaryText",
    "selectionText": "$m3selectionText",
    "borderSecondary": "$m3borderSecondary"
}
EOF

    # Keep full nucleus-shell Material colors in sync for qs -c nucleus-shell.
    local scheme_prefix="nucleus-${theme_key}"
    mkdir -p "$NUCLEUS_CONFIG_DIR" "$NUCLEUS_COLORSCHEMES_DIR"
    cat >"$NUCLEUS_COLORS_FILE" <<EOF
{
  "background": "$m3background",
  "error": "#FFB4AB",
  "error_container": "#93000A",
  "inverse_on_surface": "$m3inverseOnSurface",
  "inverse_primary": "$m3primary",
  "inverse_surface": "$m3inverseSurface",
  "on_background": "$m3onBackground",
  "on_error": "#690005",
  "on_error_container": "#FFDAD6",
  "on_primary": "$m3onPrimary",
  "on_primary_container": "$m3onPrimaryContainer",
  "on_primary_fixed": "$m3onPrimaryContainer",
  "on_primary_fixed_variant": "$m3onPrimary",
  "on_secondary": "$m3onSecondary",
  "on_secondary_container": "$m3onSecondaryContainer",
  "on_secondary_fixed": "$m3onSecondaryContainer",
  "on_secondary_fixed_variant": "$m3onSecondary",
  "on_surface": "$m3onSurface",
  "on_surface_variant": "$m3onSurfaceVariant",
  "on_tertiary": "$m3onSecondary",
  "on_tertiary_container": "$m3onSecondaryContainer",
  "on_tertiary_fixed": "$m3onSecondaryContainer",
  "on_tertiary_fixed_variant": "$m3onSecondary",
  "outline": "$m3outline",
  "outline_variant": "$m3outlineVariant",
  "primary": "$m3primary",
  "primary_container": "$m3primaryContainer",
  "primary_fixed": "$m3onPrimaryContainer",
  "primary_fixed_dim": "$m3primary",
  "scrim": "#000000",
  "secondary": "$m3secondary",
  "secondary_container": "$m3secondaryContainer",
  "secondary_fixed": "$m3onSecondaryContainer",
  "secondary_fixed_dim": "$m3secondary",
  "shadow": "$m3shadow",
  "source_color": "$m3primary",
  "surface": "$m3surface",
  "surface_bright": "$m3surfaceContainerHighest",
  "surface_container": "$m3surfaceContainer",
  "surface_container_high": "$m3surfaceContainerHigh",
  "surface_container_highest": "$m3surfaceContainerHighest",
  "surface_container_low": "$m3surfaceContainerLow",
  "surface_container_lowest": "$m3windowBackground",
  "surface_dim": "$m3background",
  "surface_tint": "$m3primary",
  "surface_variant": "$m3surfaceVariant",
  "tertiary": "$m3accentSecondary",
  "tertiary_container": "$m3secondaryContainer",
  "tertiary_fixed": "$m3onSecondaryContainer",
  "tertiary_fixed_dim": "$m3accentSecondary"
}
EOF

    cp -f "$NUCLEUS_COLORS_FILE" "$NUCLEUS_COLORSCHEMES_DIR/${scheme_prefix}-dark.json"

    if have jq; then
        if [[ ! -f "$NUCLEUS_CONFIG_FILE" ]]; then
            printf '{}\n' >"$NUCLEUS_CONFIG_FILE"
        fi
        local tmp_cfg
        tmp_cfg="$(mktemp)"
        if jq --arg scheme "$scheme_prefix" '
            .appearance = (.appearance // {}) |
            .appearance.theme = "dark" |
            .appearance.colors = (.appearance.colors // {}) |
            .appearance.colors.autogenerated = false |
            .appearance.colors.scheme = $scheme
        ' "$NUCLEUS_CONFIG_FILE" >"$tmp_cfg"; then
            mv "$tmp_cfg" "$NUCLEUS_CONFIG_FILE"
        else
            rm -f "$tmp_cfg"
        fi
    fi

    # Keep Nucleus quick-settings colors in sync.
    mkdir -p "$(dirname "$THEME_STATE_FILE")"
    cat >"$THEME_STATE_FILE" <<EOF
# Auto-generated by Nucleus_Shell_ThemeSelector.sh
COL_TEXT="$col_text"
COL_MUTED="$col_muted"
COL_PRIMARY="$col_primary"
COL_ON="$col_on"
COL_OFF="$col_off"
COL_SECURE="$col_secure"
COL_OPEN="$col_open"
COL_DIM="$col_dim"
COL_ACTION="$col_action"
EOF

    # Optional rofi quick-settings synchronization (disabled by default).
    if [[ "${SYNC_ROFI_THEME:-0}" == "1" && -f "$ROFI_THEME" ]]; then
        set_rasi_var "$ROFI_THEME" "bg" "$rofi_bg"
        set_rasi_var "$ROFI_THEME" "bg-alt" "$rofi_bg_alt"
        set_rasi_var "$ROFI_THEME" "card" "$rofi_card"
        set_rasi_var "$ROFI_THEME" "card-active" "$rofi_card_active"
        set_rasi_var "$ROFI_THEME" "fg" "$rofi_fg"
        set_rasi_var "$ROFI_THEME" "muted" "$rofi_muted"
        set_rasi_var "$ROFI_THEME" "border-col" "$rofi_border"
        set_rasi_var "$ROFI_THEME" "selected-bg" "$rofi_selected_bg"
        set_rasi_var "$ROFI_THEME" "selected-fg" "$rofi_selected_fg"
        perl -0pi -e "s@(prompt\\s*\\{[^}]*?text-color:\\s*)#[0-9A-Fa-f]{6}(\\s*;)@\\1${rofi_prompt}\\2@s" "$ROFI_THEME"
    fi

    if [[ -f "$SWAYNC_STYLE" ]]; then
        set_css_color "$SWAYNC_STYLE" "m3-bg" "$m3background"
        set_css_color "$SWAYNC_STYLE" "m3-surface" "$m3surface"
        set_css_color "$SWAYNC_STYLE" "m3-surface-low" "$m3surfaceContainerLow"
        set_css_color "$SWAYNC_STYLE" "m3-surface-card" "$m3surfaceContainer"
        set_css_color "$SWAYNC_STYLE" "m3-surface-hi" "$m3surfaceContainerHigh"
        set_css_color "$SWAYNC_STYLE" "m3-text" "$m3onSurface"
        set_css_color "$SWAYNC_STYLE" "m3-text-soft" "$m3onSurfaceVariant"
        set_css_color "$SWAYNC_STYLE" "m3-outline" "$m3outlineVariant"
        set_css_color "$SWAYNC_STYLE" "m3-outline-soft" "$m3outline"
        set_css_color "$SWAYNC_STYLE" "m3-primary" "$m3primary"
        set_css_color "$SWAYNC_STYLE" "m3-on-primary" "$m3onPrimary"
        set_css_color "$SWAYNC_STYLE" "m3-primary-container" "$m3primaryContainer"
        set_css_color "$SWAYNC_STYLE" "m3-on-primary-container" "$m3onPrimaryContainer"
        set_css_color "$SWAYNC_STYLE" "m3-secondary-container" "$m3secondaryContainer"
        set_css_color "$SWAYNC_STYLE" "m3-on-secondary-container" "$m3onSecondaryContainer"
        set_css_color "$SWAYNC_STYLE" "m3-error" "#FFB4AB"
        set_css_color "$SWAYNC_STYLE" "m3-on-error" "#690005"
        set_css_rgba "$SWAYNC_STYLE" "m3-shadow" "rgba(0, 0, 0, 0.56)"
        restart_swaync
    fi

    # Keep HyprWave theme aligned with the selected palette when possible.
    local hyprwave_theme="$theme_key"
    case "$theme_key" in
        orchid) hyprwave_theme="nucleus-orchid" ;;
        emerald) hyprwave_theme="nucleus-iris" ;;
        amber) hyprwave_theme="nucleus-sand" ;;
    esac
    if [[ -f "$HOME/.config/hyprwave/themes/${hyprwave_theme}.css" ]]; then
        mkdir -p "$HOME/.local/share/hyprwave/themes" >/dev/null 2>&1 || true
        cp -f "$HOME/.config/hyprwave/themes/${hyprwave_theme}.css" "$HOME/.local/share/hyprwave/themes/${hyprwave_theme}.css" >/dev/null 2>&1 || true
    fi
    if have hyprwave-toggle; then
        hyprwave-toggle set-theme "$hyprwave_theme" >/dev/null 2>&1 || true
    fi

    # Restart quickshell (if running) using whichever profile is active.
    local running_profile
    local restarted_profile
    running_profile="$(detect_qs_profile)"
    if [[ "$running_profile" != "stopped" ]]; then
        if restarted_profile="$(restart_qs_with_fallback "$running_profile")"; then
            if [[ "$restarted_profile" != "$running_profile" && "$running_profile" != "unknown" ]]; then
                notify_low "Nucleus Theme" "Applied ${theme_key}. HyprWave + quickshell updated (fallback profile: ${restarted_profile})."
            else
                notify_low "Nucleus Theme" "Applied ${theme_key}. Updated HyprWave + quickshell palette."
            fi
        else
            notify_low "Nucleus Theme" "Applied ${theme_key}. HyprWave updated, but quickshell restart failed."
        fi
    else
        notify_low "Nucleus Theme" "Applied ${theme_key}. HyprWave + palette files updated. Start QuickShell with: $START_QUICKSHELL start"
    fi
}

main() {
    local theme_key="${1:-}"

    if [[ -z "$theme_key" ]]; then
        if ! have rofi; then
            notify_low "Nucleus Theme" "rofi is not installed"
            exit 1
        fi
        local choice
        choice="$(
            printf '%s\n' \
                "Nucleus Orchid (Default)" \
                "Nucleus Emerald" \
                "Nucleus Amber" \
                "Persona 3 Reload" \
                "Persona 4 Golden" \
                "Persona 5 Royal" \
                "Gruvbox" \
                "Catppuccin" \
                "Mystic Portal" \
                "Tokyo Night" \
                "Kanagawa" \
                "Rose Pine" \
            | rofi -dmenu -i -no-custom -config "$ROFI_THEME" \
                -p "Nucleus Theme" \
                -mesg "<span foreground='#E5B6F2'>Pick a theme for Nucleus shell and HyprWave.</span>"
        )"
        [[ -z "${choice:-}" ]] && exit 0
        case "$choice" in
            "Nucleus Orchid (Default)") theme_key="orchid" ;;
            "Nucleus Emerald") theme_key="emerald" ;;
            "Nucleus Amber") theme_key="amber" ;;
            "Persona 3 Reload") theme_key="persona3-reload" ;;
            "Persona 4 Golden") theme_key="persona4-golden" ;;
            "Persona 5 Royal") theme_key="persona5-royal" ;;
            "Gruvbox") theme_key="gruvbox" ;;
            "Catppuccin") theme_key="catppuccin" ;;
            "Mystic Portal") theme_key="mystic-portal" ;;
            "Tokyo Night") theme_key="tokyonight" ;;
            "Kanagawa") theme_key="kanagawa" ;;
            "Rose Pine") theme_key="rose-pine" ;;
            *) notify_low "Nucleus Theme" "Unknown selection"; exit 1 ;;
        esac
    fi

    apply_palette "$theme_key"
}

main "$@"
