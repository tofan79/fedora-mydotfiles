#!/usr/bin/env bash
cache_file="$HOME/.cache/gaming_mode"
if [ -f "$cache_file" ]; then
    hyprctl eval "hl.config({ animations = { enabled = true }, decoration = { rounding = 12, active_opacity = 0.9, inactive_opacity = 0.7, fullscreen_opacity = 0.9, blur = { enabled = true, size = 3, passes = 2, new_optimizations = true, ignore_opacity = true, xray = true }, shadow = { enabled = true, range = 30, render_power = 3, color = '0x66000000' } }, general = { gaps_in = 5, gaps_out = 10, border_size = 2 } })"
    rm "$cache_file"
    notify-send -u low "Boost Mode: OFF" "Dekorasi & animasi normal"
else
    hyprctl eval "hl.config({ animations = { enabled = false }, decoration = { rounding = 0, active_opacity = 1.0, inactive_opacity = 0.9, fullscreen_opacity = 1.0, blur = { enabled = false }, shadow = { enabled = false } }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })"
    touch "$cache_file"
    notify-send -u low "Boost Mode: ON" "Semua dekorasi off (main game)"
fi
