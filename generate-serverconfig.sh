#!/bin/bash
# Generate serverconfig.txt from environment variables. Run from entrypoint when TERRARIA_USECONFIGFILE=Yes and TERRARIA_GENERATE_FROM_ENV != No.

set -e

readonly WORLDS_DIR="${WORLDS_DIR:-/root/.local/share/Terraria/Worlds}"
readonly OUT_FILE="${OUT_FILE:-/root/terraria-server/serverconfig.txt}"

WORLDNAME="${TERRARIA_WORLDNAME:-Docker}"
WORLDSIZE="${TERRARIA_WORLDSIZE:-3}"
WORLDSEED="${TERRARIA_WORLDSEED:-Docker}"
MAXPLAYERS="${TERRARIA_MAXPLAYERS:-8}"
PASS="${TERRARIA_PASS:-}"
MOTD="${TERRARIA_MOTD:-A Terraria server}"
DIFFICULTY="${TERRARIA_DIFFICULTY:-2}"
NPCSTREAM="${TERRARIA_NPCSTREAM:-1}"
PORT="${TERRARIA_PORT:-7777}"

# World path inside container (must match volume mount)
WORLD_PATH="$WORLDS_DIR/$WORLDNAME.wld"

mkdir -p "$(dirname "$OUT_FILE")"
mkdir -p "$WORLDS_DIR"

# Write serverconfig.txt in Terraria format (key=value, one option per line)
{
  echo "# Generated from env by generate-serverconfig.sh - do not edit by hand when using env"
  echo "world=$WORLD_PATH"
  echo "worldname=$WORLDNAME"
  echo "worldpath=$WORLDS_DIR"
  echo "autocreate=$WORLDSIZE"
  echo "seed=$WORLDSEED"
  echo "maxplayers=$MAXPLAYERS"
  [[ -n "$PASS" && "$PASS" != "N/A" ]] && echo "password=$PASS" || echo "password="
  echo "motd=$MOTD"
  echo "difficulty=$DIFFICULTY"
  echo "npcstream=$NPCSTREAM"
  echo "port=$PORT"
} > "$OUT_FILE"

echo "[INFO] Generated serverconfig.txt from env at $OUT_FILE"
echo "  world=$WORLD_PATH | worldname=$WORLDNAME | difficulty=$DIFFICULTY | maxplayers=$MAXPLAYERS"
