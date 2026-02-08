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

# Create Worlds directory (Terraria will also create it, but we ensure it exists)
mkdir -p "$WORLDS_DIR"
# Ensure proper permissions for world directory
chmod 755 "$WORLDS_DIR"
chown -R root:root "$WORLDS_DIR" 2>/dev/null || true

# Log where worlds are stored
echo "[INFO] World files will be saved to: $WORLDS_DIR"
if [[ -n "${TERRARIA_DATA_PATH:-}" ]]; then
  echo "[INFO] This maps to host path: ${TERRARIA_DATA_PATH}/Worlds"
else
  echo "[INFO] Host path mapping: <not set>"
fi

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
    echo "[INFO] World creation parameters:"
    echo "  - Path: $world_path"
    echo "  - Size: ${TERRARIA_WORLDSIZE:-3} (1=Small, 2=Medium, 3=Large)"
    echo "  - Name: ${TERRARIA_WORLDNAME:-Docker}"
    echo "  - Seed: ${TERRARIA_WORLDSEED:-Docker}"
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
  world_size_num="${TERRARIA_WORLDSIZE:-3}"
  max_wait=600  # Wait up to 10 minutes (large worlds take time)
  elapsed=0
  check_interval=10
  
  # Large worlds (size 3) can take 5-10 minutes to generate
  if [[ "$world_size_num" == "3" ]]; then
    echo "[INFO] Large world detected - generation may take 5-10 minutes..."
  fi
  
  while [[ $elapsed -lt $max_wait ]] && [[ ! -e "$world_path" ]]; do
    sleep $check_interval
    elapsed=$((elapsed + check_interval))
    
    # Check if world file is being created (partial file exists)
    if [[ -e "${world_path}.tmp" ]] || [[ -e "${world_path}.tmp.bak" ]]; then
      echo "[INFO] World creation in progress... (${elapsed}s elapsed)"
    elif [[ $((elapsed % 60)) -eq 0 ]]; then
      echo "[INFO] Still waiting for world creation... (${elapsed}s / ${max_wait}s elapsed)"
      echo "[INFO] Checking server status and world directory..."
      ls -lh "$WORLDS_DIR" 2>/dev/null | head -5 || echo "  (directory empty or not accessible)"
    fi
    
    # Check if server is still running
    if ! pgrep -f "TerrariaServer.bin" >/dev/null 2>&1; then
      echo "[!!] ERROR: Server process exited during world creation!"
      exit 1
    fi
    
    # Check for any .wld files that might have been created with different name
    if ls "$WORLDS_DIR"/*.wld 1>/dev/null 2>&1; then
      echo "[INFO] Found world files in directory:"
      ls -lh "$WORLDS_DIR"/*.wld 2>/dev/null
    fi
  done
  
  if [[ -e "$world_path" ]]; then
    world_size=$(du -h "$world_path" | cut -f1)
    echo "[SUCCESS] World \"$world_name\" created successfully! Size: $world_size"
  else
    echo "[WARNING] World file not found after ${elapsed}s."
    echo "[INFO] Listing all files in world directory:"
    ls -lah "$WORLDS_DIR" 2>/dev/null || echo "  (directory empty or not accessible)"
    echo "[INFO] Server is still running. World may be creating in background."
    echo "[INFO] You can check world creation progress by connecting to the server."
  fi
fi

wait ${!}
