#!/bin/sh
# Send a command to the Terraria server tmux session (e.g. docker exec <container> inject "save")

[ -z "$*" ] && exit 0
tmux send-keys -t 0 "$*" Enter
