#!/bin/bash


# read control file and initialize variables

export scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"
waybar_dir="${confDir}/waybar"
modules_dir="$waybar_dir/modules"
conf_file="$waybar_dir/config.jsonc"
conf_ctl="$waybar_dir/config.ctl"

readarray -t read_ctl < $conf_ctl
num_files="${#read_ctl[@]}"
switch=0


format_label()
{
    local idx="$1"
    IFS='|' read -r _flag height position _left _center _right <<< "${read_ctl[idx]}"
    [ -z "${height}" ] && height="auto"
    printf "%02d  %s  %spx" "$((idx + 1))" "${position}" "${height}"
}


theme_meta()
{
    local key="$1"
    local file="$2"
    local value=""

    value="$(grep -m1 "^# hyde-meta: ${key}=" "${file}" | cut -d= -f2-)"
    if [ -z "${value}" ] && [ "${key}" = "icon-theme" ] ; then
        value="$(grep 'gsettings set org.gnome.desktop.interface icon-theme' "${file}" | awk -F "'" '{print $((NF - 1))}')"
    fi

    printf '%s\n' "${value}"
}


pick_menu_mode()
{
    [[ "${rofiScale}" =~ ^[0-9]+$ ]] || rofiScale=10
    [[ "${hypr_border}" =~ ^[0-9]+$ ]] || hypr_border=2

    rofi_conf="${confDir}/rofi/selector.rasi"
    r_scale="configuration {font: \"JetBrainsMono Nerd Font ${rofiScale}\";}"
    elem_border=$(( hypr_border * 5 ))
    r_override="window{width:35%;} element{border-radius:${elem_border}px;}"

    active_label=""
    menu_entries=()
    for i in "${!read_ctl[@]}" ; do
        if [ "$(echo "${read_ctl[i]}" | cut -d '|' -f 1)" = "1" ] ; then
            active_label="$(format_label "${i}")"
        fi
        menu_entries+=("$(format_label "${i}")")
    done

    selected=$(printf '%s\n' "${menu_entries[@]}" | rofi -dmenu -theme-str "${r_scale}" -theme-str "${r_override}" -config "${rofi_conf}" -select "${active_label}")
    [ -z "${selected}" ] && return 1

    nextIndex=$((10#${selected%% *} - 1))
    switch=1
}


pick_random_mode()
{
    currentIndex=0
    for (( i=0 ; i<num_files ; i++ )) ; do
        if [ "$(echo "${read_ctl[i]}" | cut -d '|' -f 1)" = "1" ] ; then
            currentIndex=$i
            break
        fi
    done

    if [ "${num_files}" -le 1 ] ; then
        nextIndex="${currentIndex}"
    else
        while : ; do
            nextIndex=$(( RANDOM % num_files ))
            [ "${nextIndex}" -ne "${currentIndex}" ] && break
        done
    fi
    switch=1
}


case "${1}" in
    m|-m|--menu) pick_menu_mode ;;
    r|-r|--random) pick_random_mode ;;
esac


# update control file to set next/prev mode

if [ $num_files -gt 1 ] && [ $switch -eq 0 ]
then
    for (( i=0 ; i<$num_files ; i++ ))
    do
        flag=`echo "${read_ctl[i]}" | cut -d '|' -f 1`
        if [ $flag -eq 1 ] && [[ "$1" == "n" || "$1" == "-n" || "$1" == "--next" ]] ; then
            nextIndex=$(( (i + 1) % $num_files ))
            switch=1
            break;

        elif [ $flag -eq 1 ] && [[ "$1" == "p" || "$1" == "-p" || "$1" == "--prev" ]] ; then
            nextIndex=$(( i - 1 ))
            switch=1
            break;
        fi
    done
fi

if [ $switch -eq 1 ] ; then
    update_ctl="${read_ctl[nextIndex]}"
    reload_flag=1
    sed -i "s/^1/0/g" $conf_ctl
    awk -F '|' -v cmp="$update_ctl" '{OFS=FS} {if($0==cmp) $1=1; print$0}' $conf_ctl > $waybar_dir/tmp && mv $waybar_dir/tmp $conf_ctl
fi


# overwrite config from header module

export set_sysname=`hostnamectl hostname`
export w_position=`grep '^1|' $conf_ctl | cut -d '|' -f 3`

case ${w_position} in
    left) export hv_pos="width" ; export r_deg=90 ;;
    right) export hv_pos="width" ; export r_deg=270 ;;
    *) export hv_pos="height" ; export r_deg=0 ;;
esac

export w_height=`grep '^1|' $conf_ctl | cut -d '|' -f 2`
if [ -z $w_height ] ; then
    y_monres=`cat /sys/class/drm/*/modes | head -1 | cut -d 'x' -f 2`
    export w_height=$(( y_monres*2/100 ))
fi

export i_size=$(( w_height*6/10 ))
if [ $i_size -lt 12 ] ; then
    export i_size="12"
fi

export i_theme="$(theme_meta icon-theme "${hydeThemeDir}/hypr.theme")"
[ -z "${i_theme}" ] && export i_theme="$(sed -n 's/^gtk-icon-theme-name=//p' "${confDir}/gtk-3.0/settings.ini" | head -n 1)"
export i_task=$(( w_height*6/10 ))
if [ $i_task -lt 16 ] ; then
    export i_task="16"
fi

envsubst < $modules_dir/header.jsonc > $conf_file


# module generator function

gen_mod()
{
    local pos=$1
    local col=$2
    local mod=""

    mod=`grep '^1|' $conf_ctl | cut -d '|' -f ${col}`
    mod="${mod//(/"custom/l_end"}"
    mod="${mod//)/"custom/r_end"}"
    mod="${mod//[/"custom/sl_end"}"
    mod="${mod//]/"custom/sr_end"}"
    mod="${mod//\{/"custom/rl_end"}"
    mod="${mod//\}/"custom/rr_end"}"
    mod="${mod// /"\",\""}"

    echo -e "\t\"modules-${pos}\": [\"custom/padd\",\"${mod}\",\"custom/padd\"]," >> $conf_file
    write_mod=`echo $write_mod $mod`
}


# write positions for modules

echo -e "\n\n// positions generated based on config.ctl //\n" >> $conf_file
gen_mod left 4
gen_mod center 5
gen_mod right 6


# copy modules/*.jsonc to the config

echo -e "\n\n// sourced from modules based on config.ctl //\n" >> $conf_file
echo "$write_mod" | sed 's/","/\n/g ; s/ /\n/g' | awk -F '/' '{print $NF}' | awk -F '#' '{print $1}' | awk '!x[$0]++' | while read mod_cpy
do
    if [ -f $modules_dir/$mod_cpy.jsonc ] ; then
        envsubst < $modules_dir/$mod_cpy.jsonc >> $conf_file
    fi
done

cat $modules_dir/footer.jsonc >> $conf_file


# generate style

$scrDir/wbarstylegen.sh


# restart waybar

if [ "$reload_flag" == "1" ] ; then
    killall waybar
    waybar --config ${waybar_dir}/config.jsonc --style ${waybar_dir}/style.css > /dev/null 2>&1 &
fi
