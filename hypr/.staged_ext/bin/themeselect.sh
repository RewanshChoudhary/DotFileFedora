#!/bin/bash


#// set variables

scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"
rofiConf="${confDir}/rofi/selector.rasi"


usage() {
    cat <<'EOF'
Usage: themeselect.sh [option]
  -m, --menu      Open the theme selector menu
  -n, --next      Switch to the next theme
  -p, --prev      Switch to the previous theme
  -r, --random    Switch to a random theme
EOF
}


notify_theme() {
    source "${scrDir}/globalcontrol.sh"
    notify-send -a "t1" -i "$HOME/.config/dunst/icons/hyprdots.png" " ${hydeTheme}"
}


apply_theme() {
    local mode="$1"
    shift || true
    "${scrDir}/themeswitch.sh" "${mode}" "$@"
    notify_theme
}


pick_random_theme() {
    get_themes
    [ "${#thmList[@]}" -eq 0 ] && exit 1

    themePick="${thmList[RANDOM % ${#thmList[@]}]}"
    if [ "${#thmList[@]}" -gt 1 ] ; then
        while [ "${themePick}" = "${hydeTheme}" ] ; do
            themePick="${thmList[RANDOM % ${#thmList[@]}]}"
        done
    fi

    apply_theme -s "${themePick}"
}


show_menu() {
    #// set rofi scaling

    [[ "${rofiScale}" =~ ^[0-9]+$ ]] || rofiScale=10
    [[ "${hypr_border}" =~ ^[0-9]+$ ]] || hypr_border=2
    r_scale="configuration {font: \"JetBrainsMono Nerd Font ${rofiScale}\";}"
    elem_border=$(( hypr_border * 5 ))
    icon_border=$(( elem_border - 5 ))


    #// scale for monitor

    mon_x_res=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .width')
    mon_scale=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .scale' | sed "s/\.//")
    mon_x_res=$(( mon_x_res * 100 / mon_scale ))


    #// generate config

    case "${themeSelect}" in
    2) # adapt to style 2
        elm_width=$(( (20 + 12) * rofiScale * 2 ))
        max_avail=$(( mon_x_res - (4 * rofiScale) ))
        col_count=$(( max_avail / elm_width ))
        r_override="window{width:100%;background-color:#00000003;} listview{columns:${col_count};} element{border-radius:${elem_border}px;background-color:@main-bg;} element-icon{size:20em;border-radius:${icon_border}px 0px 0px ${icon_border}px;}"
        thmbExtn="quad" ;;
    *) # default to style 1
        elm_width=$(( (23 + 12 + 1) * rofiScale * 2 ))
        max_avail=$(( mon_x_res - (4 * rofiScale) ))
        col_count=$(( max_avail / elm_width ))
        r_override="window{width:100%;} listview{columns:${col_count};} element{border-radius:${elem_border}px;padding:0.5em;} element-icon{size:23em;border-radius:${icon_border}px;}"
        thmbExtn="sqre" ;;
    esac


    #// launch rofi menu

    get_themes

    rofiSel=$(for i in ${!thmList[@]} ; do
        echo -en "${thmList[i]}\x00icon\x1f${thmbDir}/$(set_hash "${thmWall[i]}").${thmbExtn}\n"
    done | rofi -dmenu -theme-str "${r_scale}" -theme-str "${r_override}" -config "${rofiConf}" -select "${hydeTheme}")


    #// apply theme

    if [ -n "${rofiSel}" ] ; then
        apply_theme -s "${rofiSel}"
    fi
}

case "${1}" in
    ""|-m|--menu) show_menu ;;
    -n|--next) apply_theme -n ;;
    -p|--prev) apply_theme -p ;;
    -r|--random) pick_random_theme ;;
    -h|--help) usage ;;
    *) usage; exit 1 ;;
esac
