#!/bin/bash
# Toggle outer gaps between normal and wide mode (recording/streaming)
CONFIG_FILE="$HOME/.config/mango/settings.conf"
STATE_FILE="$HOME/.config/mango/.recording_mode"

if [ -f "$STATE_FILE" ]; then
    NEW_GAPPOH=10
    MODE="Normal"
    rm "$STATE_FILE"
else
    NEW_GAPPOH=450
    MODE="Recording"
    touch "$STATE_FILE"
fi

sed -i "s/^gappoh=.*/gappoh=$NEW_GAPPOH/" "$CONFIG_FILE"

mmsg -d reload_config
notify-send "Mode: $MODE" "Gaps: ${NEW_GAPPOH}px"
