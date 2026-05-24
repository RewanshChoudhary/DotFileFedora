#!/bin/bash


#// set variables

scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"
rofiConf="${confDir}/rofi/selector.rasi"
rofiStyleDir="${confDir}/rofi/styles"
rofiAssetDir="${confDir}/rofi/assets"


usage() {
    cat <<'EOF'
Usage: rofiselect.sh [option]
  -m, --menu      Open the rofi style selector menu
  -n, --next      Switch to the next rofi style
  -p, --prev      Switch to the previous rofi style
  -r, --random    Switch to a random rofi style
EOF
}


get_styles() {
    mapfile -t rofiStyles < <(find "${rofiStyleDir}" -maxdepth 1 -type f -name 'style_*.rasi' -printf '%f\n' | sed -E 's/^style_([0-9]+)\.rasi$/\1/' | sort -n)
}


apply_style() {
    local styleNum="$1"
    [ -z "${styleNum}" ] && return 1
    set_conf "rofiStyle" "${styleNum}"
    notify-send -a "t1" -r 91190 -t 2200 -i "${rofiAssetDir}/style_${styleNum}.png" " style ${styleNum} applied..."
}


cycle_style() {
    local direction="$1"
    get_styles
    [ "${#rofiStyles[@]}" -eq 0 ] && exit 1

    local active_index=0
    for i in "${!rofiStyles[@]}" ; do
        if [ "${rofiStyles[i]}" = "${rofiStyle}" ] ; then
            active_index="${i}"
            break
        fi
    done

    if [ "${direction}" = "n" ] ; then
        active_index=$(( (active_index + 1) % ${#rofiStyles[@]} ))
    else
        active_index=$(( active_index - 1 ))
        [ "${active_index}" -lt 0 ] && active_index=$((${#rofiStyles[@]} - 1))
    fi

    apply_style "${rofiStyles[active_index]}"
}


random_style() {
    get_styles
    [ "${#rofiStyles[@]}" -eq 0 ] && exit 1

    local selected="${rofiStyles[RANDOM % ${#rofiStyles[@]}]}"
    if [ "${#rofiStyles[@]}" -gt 1 ] ; then
        while [ "${selected}" = "${rofiStyle}" ] ; do
            selected="${rofiStyles[RANDOM % ${#rofiStyles[@]}]}"
        done
    fi

    apply_style "${selected}"
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

    elm_width=$(( (20 + 12 + 16 ) * rofiScale ))
    max_avail=$(( mon_x_res - (4 * rofiScale) ))
    col_count=$(( max_avail / elm_width ))
    [[ "${col_count}" -gt 5 ]] && col_count=5
    r_override="window{width:100%;} listview{columns:${col_count};} element{orientation:vertical;border-radius:${elem_border}px;} element-icon{border-radius:${icon_border}px;size:20em;} element-text{enabled:false;}"


    #// launch rofi menu

    get_styles

    RofiSel=$(for styleNum in "${rofiStyles[@]}" ; do
        echo -en "${styleNum}\x00icon\x1f${rofiAssetDir}/style_${styleNum}.png\n"
    done | rofi -dmenu -theme-str "${r_scale}" -theme-str "${r_override}" -config "${rofiConf}" -select "${rofiStyle}")


    #// apply rofi style

    if [ -n "${RofiSel}" ] ; then
        apply_style "${RofiSel}"
    fi
}

case "${1}" in
    ""|-m|--menu) show_menu ;;
    -n|--next) cycle_style n ;;
    -p|--prev) cycle_style p ;;
    -r|--random) random_style ;;
    -h|--help) usage ;;
    *) usage; exit 1 ;;
esac
