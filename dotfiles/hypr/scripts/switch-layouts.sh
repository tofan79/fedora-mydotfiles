#!/usr/bin/env bash
items=("Deck Stack" "Dwindle" "Fair Grid" "Master" "Monocle" "Scrolling")
declare -A map
map["Deck Stack"]="lua:deck"
map["Dwindle"]="dwindle"
map["Fair Grid"]="lua:fair"
map["Master"]="master"
map["Monocle"]="monocle"
map["Scrolling"]="scrolling"

selection=$(printf "%s\n" "${items[@]}" | rofi -dmenu -p "Layout" -matching fuzzy -i -config ~/.config/rofi/config-keybinds.rasi)
[[ -z "$selection" ]] && exit 0

id=$(hyprctl activeworkspace -j | tr ',' '\n' | sed -n 's/.*"id": *\([0-9]*\).*/\1/p')
hyprctl eval "hl.workspace_rule({ workspace = tostring($id), layout = '${map[$selection]}' })" && notify-send -u low "Layout" "Switched to $selection"
