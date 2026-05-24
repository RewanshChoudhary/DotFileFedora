#!/bin/bash


#// set variables

scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"
[ -z "${hydeTheme}" ] && echo "ERROR: unable to detect theme" && exit 1
get_themes

theme_template_path()
{
    case "${1}" in
        "Catppuccin Latte") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Catppuccin_Latte.hypr.theme" ;;
        "Catppuccin Mocha") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Catppuccin_Mocha.hypr.theme" ;;
        "Decay Green") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Decay_Green.hypr.theme" ;;
        "Edge Runner") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Edge_Runner.hypr.theme" ;;
        "Frosted Glass") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Frosted_Glass.hypr.theme" ;;
        "Graphite Mono") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Graphite_Mono.hypr.theme" ;;
        "Gruvbox Retro") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Gruvbox_Retro.hypr.theme" ;;
        "Material Sakura") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Material_Sakura.hypr.theme" ;;
        "Nordic Blue") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Nordic_Blue.hypr.theme" ;;
        "Rosé Pine") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Rose_Pine.hypr.theme" ;;
        "Synth Wave") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Synth_Wave.hypr.theme" ;;
        "Tokyo Night") echo "/home/rewansh57/.config/hypr/.staged_ext/hyde/Tokyo_Night.hypr.theme" ;;
        *) echo "${hydeThemeDir}/hypr.theme" ;;
    esac
}

#// define functions

Theme_Change()
{
    local x_switch=$1
    for i in ${!thmList[@]} ; do
        if [ "${thmList[i]}" == "${hydeTheme}" ] ; then
            if [ "${x_switch}" == 'n' ] ; then
                setIndex=$(( (i + 1) % ${#thmList[@]} ))
            elif [ "${x_switch}" == 'p' ] ; then
                setIndex=$(( i - 1 ))
            fi
            themeSet="${thmList[setIndex]}"
            break
        fi
    done
}


#// evaluate options

while getopts "nps:" option ; do
    case $option in

    n ) # set next theme
        Theme_Change n
        export xtrans="grow" ;;

    p ) # set previous theme
        Theme_Change p
        export xtrans="outer" ;;

    s ) # set selected theme
        themeSet="$OPTARG" ;;

    * ) # invalid option
        echo "... invalid option ..."
        echo "$(basename "${0}") -[option]"
        echo "n : set next theme"
        echo "p : set previous theme"
        echo "s : set input theme"
        exit 1 ;;
    esac
done


#// update control file

if ! $(echo "${thmList[@]}" | grep -wq "${themeSet}") ; then
    themeSet="${hydeTheme}"
fi

set_conf "hydeTheme" "${themeSet}"
echo ":: applying theme :: \"${themeSet}\""
export reload_flag=1
source "${scrDir}/globalcontrol.sh"
themeTemplate="$(theme_template_path "${hydeTheme}")"


#// hypr

tmp_theme="$(mktemp "${confDir}/hypr/themes/theme.conf.XXXXXX")"
sed '1d' "${themeTemplate}" > "${tmp_theme}"
mv "${tmp_theme}" "${confDir}/hypr/themes/theme.conf"
# Keep theme switching scoped to Hyprland dotfiles only.

#// wallpaper

"${scrDir}/swwwallpaper.sh" -s "$(readlink "${hydeThemeDir}/wall.set")"
