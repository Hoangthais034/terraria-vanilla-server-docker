#!/bin/sh
# Runs in background; saves the world at TERRARIA_AUTOSAVE_INTERVAL (minutes).

interval="${TERRARIA_AUTOSAVE_INTERVAL:-10}"
while true; do
  sleep "${interval}m"
  inject "save"
  inject "say The World has been saved."
done
