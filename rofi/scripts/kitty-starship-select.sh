#!/usr/bin/env bash
# Kitty + Starship Theme Selector
# Changes kitty terminal theme AND updates starship prompt palette to match.

kitty_themes_dir="$HOME/.config/kitty/themes"
kitty_theme_conf="$HOME/.config/kitty/theme.conf"
starship_config="$HOME/.config/starship.toml"
rofi_theme="$HOME/.config/rofi/kitty-starship-select.rasi"
notif_icon="$HOME/.config/dunst/icons/hyprdots.png"
err_icon="$HOME/.config/dunst/icons/critical.svg"

notify_user() {
  notify-send -u low -i "$1" "$2" "$3"
}

get_color() {
  local file="$1" key="$2"
  grep -im1 "^${key}[[:space:]]" "$file" | awk '{print $2}' | head -1
}

apply_kitty_theme() {
  local theme_name="$1"
  local theme_file="$kitty_themes_dir/$theme_name"
  if [ ! -f "$theme_file" ]; then
    notify_user "$err_icon" "Error" "Theme not found: $theme_name"
    return 1
  fi
  cp "$theme_file" "$kitty_theme_conf"
  for pid in $(pidof kitty); do
    kill -SIGUSR1 "$pid" 2>/dev/null
  done
  return 0
}

theme_to_palette_name() {
  local base="${1%.conf}"
  case "$base" in
    Catppuccin-Mocha)      echo "catppuccin_mocha" ;;
    Catppuccin-Latte)      echo "catppuccin_latte" ;;
    Catppuccin-Frappe)     echo "catppuccin_frappe" ;;
    Catppuccin-Macchiato)  echo "catppuccin_macchiato" ;;
    *)                     echo "current" ;;
  esac
}

generate_palette() {
  local file="$1"
  local fg c0 c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11 c12 c13 c14 c15 bg

  fg=$(get_color "$file" "foreground")
  bg=$(get_color "$file" "background")
  c0=$(get_color "$file" "color0")
  c1=$(get_color "$file" "color1")
  c2=$(get_color "$file" "color2")
  c3=$(get_color "$file" "color3")
  c4=$(get_color "$file" "color4")
  c5=$(get_color "$file" "color5")
  c6=$(get_color "$file" "color6")
  c7=$(get_color "$file" "color7")
  c8=$(get_color "$file" "color8")
  c9=$(get_color "$file" "color9")
  c10=$(get_color "$file" "color10")
  c11=$(get_color "$file" "color11")
  c12=$(get_color "$file" "color12")
  c13=$(get_color "$file" "color13")
  c14=$(get_color "$file" "color14")
  c15=$(get_color "$file" "color15")

  : "${fg:=#cdd6f4}" "${bg:=#1e1e2e}"
  : "${c0:=$bg}"  "${c8:=$c0}"
  : "${c1:=#f38ba8}" "${c9:=$c1}"
  : "${c2:=#a6e3a1}" "${c10:=$c2}"
  : "${c3:=#f9e2af}" "${c11:=$c3}"
  : "${c4:=#89b4fa}" "${c12:=$c4}"
  : "${c5:=#cba6f7}" "${c13:=$c5}"
  : "${c6:=#89dceb}" "${c14:=$c6}"
  : "${c7:=$fg}"     "${c15:=$c7}"

  cat << PALEOF
[palettes.current]
rosewater = "${c9}"
flamingo  = "${c9}"
pink      = "${c13}"
mauve     = "${c5}"
red       = "${c1}"
maroon    = "${c9}"
peach     = "${c11}"
yellow    = "${c3}"
green     = "${c2}"
teal      = "${c10}"
sky       = "${c6}"
sapphire  = "${c12}"
blue      = "${c4}"
lavender  = "${c12}"
text      = "${fg}"
subtext1  = "${c7}"
subtext0  = "${c15}"
overlay2  = "${c8}"
overlay1  = "${c8}"
overlay0  = "${c0}"
surface2  = "${c8}"
surface1  = "${c0}"
surface0  = "${c0}"
base      = "${bg}"
mantle    = "${c0}"
crust     = "${c0}"
PALEOF
}

apply_starship_palette() {
  local palette_name="$1"
  local theme_file="$2"

  if [ "$palette_name" = "current" ]; then
    # Remove existing [palettes.current] section
    sed -i '/^\[palettes\.current\]/,/^\[palettes\./{ /^\[palettes\.current\]/d; /^\[palettes\./!d; }' "$starship_config"
    # Append generated palette
    generate_palette "$theme_file" >> "$starship_config"
  fi

  # Switch to the target palette
  sed -i "s/^palette = '.*'/palette = '${palette_name}'/" "$starship_config"
}

# --- Main ---

if [ ! -d "$kitty_themes_dir" ]; then
  notify_user "$err_icon" "Error" "Kitty themes directory not found"
  exit 1
fi

mapfile -t theme_files < <(find "$kitty_themes_dir" -maxdepth 1 -name "*.conf" ! -name "theme.conf" -type f | sort)

if [ ${#theme_files[@]} -eq 0 ]; then
  notify_user "$err_icon" "Error" "No kitty themes found"
  exit 1
fi

for i in "${!theme_files[@]}"; do
  basename "${theme_files[$i]}"
done > /tmp/kitty-theme-list.txt

selected=$(rofi -dmenu -i -p "Kitty + Starship Theme" \
  -mesg "Select a theme — kitty and starship update together" \
  -config "$rofi_theme" \
  < /tmp/kitty-theme-list.txt)

rm -f /tmp/kitty-theme-list.txt

if [ -z "$selected" ]; then
  exit 0
fi

if apply_kitty_theme "$selected"; then
  pal=$(theme_to_palette_name "$selected")
  apply_starship_palette "$pal" "$kitty_themes_dir/$selected"
  notify_user "$notif_icon" "Theme Applied" "${selected%.conf}"
fi

exit 0
