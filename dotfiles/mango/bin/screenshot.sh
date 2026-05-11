#!/bin/bash
# Screenshot - area selection, saves to file and copies to clipboard
FILE=~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png
grim -g "$(slurp)" "$FILE" && wl-copy < "$FILE" && notify-send "Screenshot saved & copied"
