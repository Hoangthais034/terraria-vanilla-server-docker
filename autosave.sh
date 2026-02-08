#!/bin/sh
# Runs in background; saves the world at TERRARIA_AUTOSAVE_INTERVAL (minutes).

interval="${TERRARIA_AUTOSAVE_INTERVAL:-10}"
# Wait for world to be fully created before first save (especially for new worlds)
# Wait 3 minutes initially to ensure world generation is complete
echo "[Autosave] Waiting 3 minutes for world to initialize..."
sleep 3m

while true; do
  sleep "${interval}m"
  inject "save"
  inject "say The World has been saved."
done
