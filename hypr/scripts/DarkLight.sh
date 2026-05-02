#!/usr/bin/env bash
## /* ----  https://github.com/JaKooLit  ---- */  ##
# Dark-only theme enforcer.
# Keeps the stack on dark mode and refreshes related UI components safely.

set -euo pipefail

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallpaper_base_path="$PICTURES_DIR/wallpapers/Dynamic-Wallpapers"
dark_wallpapers="$wallpaper_base_path/Dark"
hypr_config_path="$HOME/.config/hypr"
swaync_style="$HOME/.config/swaync/style.css"
ags_style="$HOME/.config/ags/user/style.css"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
notif="$HOME/.config/swaync/images/bell.png"
wallust_rofi="$HOME/.config/rofi/wallust/colors-rofi.rasi"
kitty_conf="$HOME/.config/kitty/kitty.conf"
wallust_config="$HOME/.config/wallust/wallust.toml"
qt5ct_dark="$HOME/.config/qt5ct/colors/Catppuccin-Mocha.conf"
qt6ct_dark="$HOME/.config/qt6ct/colors/Catppuccin-Mocha.conf"

for pid in waybar rofi swaync ags swaybg; do
    killall -SIGUSR1 "$pid" 2>/dev/null || true
done

swww query >/dev/null 2>&1 || swww-daemon --format xrgb

swww_cmd="swww img"
effect="--transition-bezier .43,1.19,1,.4 --transition-fps 60 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2"

echo "Dark" >"$HOME/.cache/.theme_mode"

if [[ -f "$wallust_config" ]]; then
    sed -i 's/^palette = .*/palette = "dark16"/' "$wallust_config"
fi

set_waybar_style() {
    local waybar_styles="$HOME/.config/waybar/style"
    local waybar_style_link="$HOME/.config/waybar/style.css"
    local style_file=""

    style_file="$(find -L "$waybar_styles" -maxdepth 1 -type f -name '[[]Dark[]]*.css' | shuf -n 1 || true)"
    if [[ -z "$style_file" ]]; then
        style_file="$(find -L "$waybar_styles" -maxdepth 1 -type f -name '[[]Wallust[]]*.css' | shuf -n 1 || true)"
    fi

    if [[ -n "$style_file" ]]; then
        ln -sf "$style_file" "$waybar_style_link"
    fi
}

set_waybar_style

if [[ -f "$swaync_style" ]]; then
    sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.8);/' "$swaync_style"
fi

if command -v ags >/dev/null 2>&1 && [[ -f "$ags_style" ]]; then
    sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.4);/' "$ags_style"
    sed -i '/@define-color text-color/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.7);/' "$ags_style"
    sed -i '/@define-color noti-bg-alt/s/#.*;/#111111;/' "$ags_style"
fi

if [[ -f "$kitty_conf" ]]; then
    sed -i '/^foreground /s/^foreground .*/foreground #dddddd/' "$kitty_conf"
    sed -i '/^background /s/^background .*/background #000000/' "$kitty_conf"
    sed -i '/^cursor /s/^cursor .*/cursor #dddddd/' "$kitty_conf"
fi

if pidof kitty >/dev/null 2>&1; then
    for pid_kitty in $(pidof kitty); do
        kill -SIGUSR1 "$pid_kitty" 2>/dev/null || true
    done
fi

if [[ -d "$dark_wallpapers" ]]; then
    next_wallpaper="$(find -L "$dark_wallpapers" -type f \( -iname '*.jpg' -o -iname '*.png' \) | shuf -n 1 || true)"
    if [[ -n "$next_wallpaper" ]]; then
        $swww_cmd "$next_wallpaper" $effect
    fi
fi

if [[ -f "$HOME/.config/qt5ct/qt5ct.conf" ]]; then
    sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt5ct_dark|" "$HOME/.config/qt5ct/qt5ct.conf"
fi
if [[ -f "$HOME/.config/qt6ct/qt6ct.conf" ]]; then
    sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt6ct_dark|" "$HOME/.config/qt6ct/qt6ct.conf"
fi

if command -v kvantummanager >/dev/null 2>&1; then
    kvantummanager --set catppuccin-mocha-blue >/dev/null 2>&1 || true
fi

if [[ -f "$wallust_rofi" ]]; then
    sed -i '/^background:/s/.*/background: rgba(0,0,0,0.7);/' "$wallust_rofi"
fi

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
fi

if [[ -x "${SCRIPTSDIR}/WallustSwww.sh" ]]; then
    "${SCRIPTSDIR}/WallustSwww.sh" >/dev/null 2>&1 || true
fi

sleep 0.5
if [[ -x "${SCRIPTSDIR}/Refresh.sh" ]]; then
    "${SCRIPTSDIR}/Refresh.sh" >/dev/null 2>&1 || true
fi

notify-send -u low -i "$notif" "Theme" "Dark mode stack applied"

exit 0
