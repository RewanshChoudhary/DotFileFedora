#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

WAYBAR_DIR="$HOME/.config/waybar"
CONFIG_LINK="$WAYBAR_DIR/config"
STYLE_LINK="$WAYBAR_DIR/style.css"
REFRESH_SCRIPT="$HOME/.config/hypr/scripts/Refresh.sh"
ROFI_THEME="$HOME/.config/rofi/config-waybar-layout.rasi"

PROFILES=(
  "top-catppuccin|󰄛 Top Catppuccin Capsule|[TOP] Nucleus Catppuccin Capsule|[Top] Nucleus Catppuccin Dark"
  "top-cyberpunk|󱐋 Top Cyberpunk Neon|[TOP] Nucleus Cyberpunk Neon|[Top] Nucleus Cyberpunk Dark"
  "left-everforest|󰟐 Left Everforest Rail|[LEFT] Nucleus Everforest Rail|[Left] Nucleus Everforest Dark"
  "left-monochrome|󰝤 Left Monochrome Rail|[LEFT] Nucleus Monochrome Rail|[Left] Nucleus Monochrome Dark"
  "top-sleek|󰈚 Top Sleek Clean (Current)|[TOP] Sleek|[Top] Nucleus Sleek Clean"
)

have() {
  command -v "$1" >/dev/null 2>&1
}

current_config_name() {
  basename "$(readlink -f "$CONFIG_LINK")"
}

current_style_name() {
  basename "$(readlink -f "$STYLE_LINK")" .css
}

apply_profile() {
  local key="$1"
  local rec cfg style

  for rec in "${PROFILES[@]}"; do
    IFS='|' read -r rec_key _ cfg style <<<"$rec"
    if [[ "$rec_key" == "$key" ]]; then
      ln -sf "$WAYBAR_DIR/configs/$cfg" "$CONFIG_LINK"
      ln -sf "$WAYBAR_DIR/style/$style.css" "$STYLE_LINK"
      "$REFRESH_SCRIPT" >/dev/null 2>&1 &
      disown || true
      if have notify-send; then
        notify-send -u low "Rice Profile" "Applied: $cfg + $style"
      fi
      return 0
    fi
  done

  return 1
}

cycle_profile() {
  local cfg_now style_now rec idx match_index next_index rec_key cfg style
  cfg_now="$(current_config_name)"
  style_now="$(current_style_name)"

  match_index=-1
  for idx in "${!PROFILES[@]}"; do
    rec="${PROFILES[$idx]}"
    IFS='|' read -r _ _ cfg style <<<"$rec"
    if [[ "$cfg" == "$cfg_now" && "$style" == "$style_now" ]]; then
      match_index="$idx"
      break
    fi
  done

  if (( match_index < 0 )); then
    next_index=0
  else
    next_index=$(( (match_index + 1) % ${#PROFILES[@]} ))
  fi

  IFS='|' read -r rec_key _ _ _ <<<"${PROFILES[$next_index]}"
  apply_profile "$rec_key"
}

menu_profile() {
  local cfg_now style_now rec rec_key label cfg style options=() default_row=0 idx=0 choice
  declare -A choice_to_key

  cfg_now="$(current_config_name)"
  style_now="$(current_style_name)"

  for rec in "${PROFILES[@]}"; do
    IFS='|' read -r rec_key label cfg style <<<"$rec"

    if [[ "$cfg" == "$cfg_now" && "$style" == "$style_now" ]]; then
      label=" ${label}"
      default_row="$idx"
    fi

    options+=("$label")
    choice_to_key["$label"]="$rec_key"
    idx=$((idx + 1))
  done

  choice="$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -config "$ROFI_THEME" -selected-row "$default_row" -p "Rice Profiles" -mesg "Curated top/left themes inspired by modern unixporn rices")"

  [[ -z "$choice" ]] && return 0

  if [[ -n "${choice_to_key[$choice]:-}" ]]; then
    apply_profile "${choice_to_key[$choice]}"
  fi
}

main() {
  case "${1:-menu}" in
    --cycle|cycle)
      cycle_profile
      ;;
    --apply)
      [[ -n "${2:-}" ]] || exit 1
      apply_profile "$2"
      ;;
    --list|list)
      printf '%s\n' "${PROFILES[@]}" | cut -d'|' -f1,2
      ;;
    *)
      menu_profile
      ;;
  esac
}

main "$@"
