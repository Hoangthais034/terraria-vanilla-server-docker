#!/bin/bash
set -e

readonly PIPE=/tmp/terraria.pipe
readonly WORLDS_DIR="/root/.local/share/Terraria/Worlds"
readonly SERVER_CONFIG="/root/terraria-server/serverconfig.txt"

cleanup_pipe() {
  rm -f "$PIPE" 2>/dev/null || true
}

shutdown_server() {
  inject "say ${TERRARIA_SHUTDOWN_MESSAGE:-Server is shutting down.}"
  sleep 3
  inject "exit"
  tmuxPid=$(pgrep tmux 2>/dev/null || true)
  if [[ -n "$tmuxPid" ]]; then
    terrPid=$(pgrep -P "$tmuxPid" Main 2>/dev/null || true)
    while [[ -n "$terrPid" ]] && [[ -e /proc/$terrPid ]]; do
      sleep 0.5
    done
  fi
  cleanup_pipe
}

# Check config file when enabled
if [[ "${TERRARIA_USECONFIGFILE:-No}" == "Yes" ]]; then
  if [[ ! -e "$SERVER_CONFIG" ]]; then
    echo "[!!] ERROR: Config file not found at $SERVER_CONFIG. Map the file and try again."
    exit 1
  fi
  echo "Terraria server will launch with the supplied config file."
else
  echo "Shutdown Message: ${TERRARIA_SHUTDOWN_MESSAGE:-Server is shutting down.}"
  echo "Save Interval: ${TERRARIA_AUTOSAVE_INTERVAL:-10} minutes"
  echo "World Name: ${TERRARIA_WORLDNAME:-Docker}"
  echo "World Size: ${TERRARIA_WORLDSIZE:-3} | Seed: ${TERRARIA_WORLDSEED:-Docker}"
  echo "Max Players: ${TERRARIA_MAXPLAYERS:-8}"
  echo "Server Password: ${TERRARIA_PASS:+[set]}"
  echo "MOTD: ${TERRARIA_MOTD:-A Terraria server}"
fi

mkdir -p "$WORLDS_DIR"
# Ensure proper permissions for world directory
chmod 755 "$WORLDS_DIR"
chown -R root:root "$WORLDS_DIR" 2>/dev/null || true

# Log where worlds are stored
echo "[INFO] World files will be saved to: $WORLDS_DIR"
echo "[INFO] This maps to host path: ${TERRARIA_DATA_PATH:-<not set>}"

# Resolve server binary path (versioned directory)
TERRARIA_PATH=$(find /root/terraria-server -maxdepth 1 -type d -name '[0-9]*' | head -1)
if [[ -z "$TERRARIA_PATH" ]] || [[ ! -x "$TERRARIA_PATH/Linux/TerrariaServer.bin.x86_64" ]]; then
  echo "[!!] ERROR: Terraria server binary not found."
  exit 1
fi

server="$TERRARIA_PATH/Linux/TerrariaServer.bin.x86_64 -server"

# Define world_path for monitoring (even if using config file)
world_path="$WORLDS_DIR/${TERRARIA_WORLDNAME:-Docker}.wld"

if [[ "${TERRARIA_USECONFIGFILE:-No}" == "Yes" ]]; then
  server="$server -config $SERVER_CONFIG"
else
  if [[ -e "$world_path" ]]; then
    server="$server -world \"$world_path\""
  else
    echo "[!!] WARNING: World \"${TERRARIA_WORLDNAME:-Docker}\" not found. Server will create a new world."
    sleep 2
    server="$server -world \"$world_path\" -autocreate ${TERRARIA_WORLDSIZE:-3} -worldname \"${TERRARIA_WORLDNAME:-Docker}\" -seed \"${TERRARIA_WORLDSEED:-Docker}\""
  fi
  server="$server -players ${TERRARIA_MAXPLAYERS:-8}"
  if [[ "${TERRARIA_PASS:-}" != "N/A" ]] && [[ -n "${TERRARIA_PASS:-}" ]]; then
    server="$server -pass \"$TERRARIA_PASS\""
  else
    echo "[!!] Server password disabled."
  fi
  server="$server -motd \"${TERRARIA_MOTD:-A Terraria server}\""
fi

trap shutdown_server TERM INT
trap cleanup_pipe EXIT

echo "Terraria Server is launching..."
sleep 2
mkfifo "$PIPE"
# Keep stdin open for server (avoids exit on EOF when tmux session is detached). Merge stderr so errors appear in logs.
tmux new-session -d "tail -f /dev/null | $server 2>&1 | tee $PIPE"

/root/terraria-server/autosave.sh &

cat "$PIPE" &
# If server exits immediately (e.g. exec format error on ARM), detect and exit with error
sleep 5
if ! pgrep -f "TerrariaServer.bin" >/dev/null 2>&1; then
  echo "[!!] ERROR: Terraria server process exited shortly after start. Check that the image platform matches the binary (use linux/amd64 for x86_64 server on ARM hosts)."
  exit 1
fi

# Monitor world creation if world doesn't exist
if [[ "${TERRARIA_USECONFIGFILE:-No}" != "Yes" ]] && [[ ! -e "$world_path" ]]; then
  echo "[INFO] Monitoring world creation process..."
  world_name="${TERRARIA_WORLDNAME:-Docker}"
  max_wait=300  # Wait up to 5 minutes
  elapsed=0
  check_interval=5
  
  while [[ $elapsed -lt $max_wait ]] && [[ ! -e "$world_path" ]]; do
    sleep $check_interval
    elapsed=$((elapsed + check_interval))
    
    # Check if world file is being created (partial file exists)
    if [[ -e "${world_path}.tmp" ]] || [[ -e "${world_path}.tmp.bak" ]]; then
      echo "[INFO] World creation in progress... (${elapsed}s elapsed)"
    elif [[ $((elapsed % 30)) -eq 0 ]]; then
      echo "[INFO] Still waiting for world creation... (${elapsed}s elapsed)"
    fi
    
    # Check if server is still running
    if ! pgrep -f "TerrariaServer.bin" >/dev/null 2>&1; then
      echo "[!!] ERROR: Server process exited during world creation!"
      exit 1
    fi
  done
  
  if [[ -e "$world_path" ]]; then
    world_size=$(du -h "$world_path" | cut -f1)
    echo "[SUCCESS] World \"$world_name\" created successfully! Size: $world_size"
  else
    echo "[WARNING] World file not found after ${elapsed}s. It may still be creating in the background."
    echo "[INFO] World files in directory:"
    ls -lh "$WORLDS_DIR" 2>/dev/null || echo "  (directory empty or not accessible)"
  fi
fi

wait ${!}
