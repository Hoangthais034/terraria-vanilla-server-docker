[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/yhoths)

# Terraria Server (Docker)

Run a Terraria dedicated server in Docker. Configuration is done via environment variables or an optional config file. World data is stored in a bind-mounted volume.

---

## How to use

**Prerequisites:** Docker and Docker Compose installed.

1. Clone or download this repository.
2. Copy the env template and edit it:
   ```bash
   cp .env.example .env
   # Edit .env with your values (see table below).
   ```
3. Create the host directory for world data (direct bind mount; default is `./terraria-data` in the project):
   ```bash
   mkdir -p ./terraria-data
   # Or set TERRARIA_DATA_PATH in .env to another path and create that directory.
   ```
4. Build and start the server (see "Running with Docker Compose" below).
5. Connect to the server on port 7777 (or the host port you set in `TERRARIA_PORT`).

To send commands into the running server from the host:
```bash
docker exec terraria inject "say Hello everyone"
docker exec terraria inject "save"
```

---

## Env template

Use this as a reference. Copy `.env.example` to `.env` and change the values.

```env
# Terraria Server - Environment variables template
# Copy this file to .env and edit the values as needed.

ENV_FILE=.env

TERRARIA_VERSION=1453
TERRARIA_SHUTDOWN_MESSAGE=Server is shutting down NOW!
TERRARIA_AUTOSAVE_INTERVAL=10
TERRARIA_MOTD=Welcome to my Terraria Server!
TERRARIA_PASS=docker
TERRARIA_MAXPLAYERS=8
TERRARIA_WORLDNAME=Docker
TERRARIA_WORLDSIZE=3
TERRARIA_WORLDSEED=Docker
TERRARIA_USECONFIGFILE=No
TERRARIA_PORT=7777
TERRARIA_DATA_PATH=./terraria-data
```

---

## Environment variables and valid values

| Variable | Default | Valid / Notes |
|----------|---------|----------------|
| `ENV_FILE` | `.env` | Env file path used by docker-compose (optional). |
| `TERRARIA_VERSION` | `1453` | Terraria version without dots (e.g. 1.4.5.3 = 1453). Used at build time. |
| `TERRARIA_SHUTDOWN_MESSAGE` | `Server is shutting down NOW!` | Any string. Broadcast to players when the container stops. |
| `TERRARIA_AUTOSAVE_INTERVAL` | `10` | Integer (minutes). How often to auto-save the world. |
| `TERRARIA_MOTD` | (see .env.example) | Any string. Message of the day shown when joining. |
| `TERRARIA_PASS` | `docker` | Any string, or `N/A` to disable password. |
| `TERRARIA_MAXPLAYERS` | `8` | Integer. Maximum number of players. |
| `TERRARIA_WORLDNAME` | `Docker` | Any string. World name and base name of the .wld file. |
| `TERRARIA_WORLDSIZE` | `3` | `1` = Small, `2` = Medium, `3` = Large. **Only used when creating a new world**; existing world is unchanged on restart. |
| `TERRARIA_WORLDSEED` | `Docker` | Any string. Seed for new world generation. |
| `TERRARIA_DIFFICULTY` | `2` | `0` = Normal, `1` = Expert, `2` = Master, `3` = Journey. Used for new worlds; existing world keeps its difficulty. |
| `TERRARIA_NPCSTREAM` | `1` | `0` = off, `1` = on. Reduces enemy skipping; may use more bandwidth. |
| `TERRARIA_USECONFIGFILE` | `No` | `Yes` or `No`. If `Yes`, server uses a config file (see "Using serverconfig.txt" below). |
| `TERRARIA_CONFIG_PATH` | `./serverconfig.txt` | Host path to `serverconfig.txt` when using config file. File is mounted into container. |
| `TERRARIA_PORT` | `7777` | Host port to publish. Container always listens on 7777. |
| `TERRARIA_DATA_PATH` | `./terraria-data` | Host path for world data (direct bind mount). Relative or absolute. |

---

## Using serverconfig.txt

If the server does not apply `difficulty` / `npcstream` via env (CLI), or you want full configuration via file, use **serverconfig.txt** per [Terraria Wiki – Server config file](https://terraria.wiki.gg/wiki/Server#Server_config_file).

By default, the image **generates** `serverconfig.txt` from env (see `generate-serverconfig.sh`). To use your own file instead, set `TERRARIA_GENERATE_FROM_ENV=No`, set `TERRARIA_CONFIG_PATH` in `.env`, and uncomment the config volume in `docker-compose.yml`.

**File name:** `serverconfig.txt` (on host; name can differ but must match the path you mount).

**Folder:** Any — point `TERRARIA_CONFIG_PATH` in `.env` to that file, e.g. `./serverconfig.txt` in the project directory.

**Manual setup (when TERRARIA_GENERATE_FROM_ENV=No):**

1. Copy the example file:
   ```bash
   cp serverconfig.example.txt serverconfig.txt
   ```
2. Edit `serverconfig.txt`: set `worldname`, `world`, `password`, `motd`, `difficulty`, `npcstream`, `maxplayers`, etc.  
   Inside the container the world directory is `/root/.local/share/Terraria/Worlds/`. Example for world name `Gensokyo`:
   - `world=/root/.local/share/Terraria/Worlds/Gensokyo.wld`
   - `worldname=Gensokyo`
3. In `.env` set:
   - `TERRARIA_GENERATE_FROM_ENV=No`
   - `TERRARIA_CONFIG_PATH=./serverconfig.txt` (or absolute path to your file)
4. **Create the file before running** — if `serverconfig.txt` does not exist, Docker may create a directory instead of mounting a file. Run `docker compose up` after the file exists.

**Format (Terraria Wiki):** One option per line, `key=value`. Lines starting with `#` are comments. Examples:

- `difficulty=2` — 0=Normal, 1=Expert, 2=Master, 3=Journey  
- `npcstream=1` or `npcstream=60` — reduces enemy skipping (0=off)  
- `autocreate=3` — 1=Small, 2=Medium, 3=Large  
- `world=`, `worldpath=`, `worldname=`, `maxplayers=`, `port=`, `password=`, `motd=`, `secure=`, `language=`, etc.

**Inside the container** the file is mounted at: `/root/terraria-server/serverconfig.txt`.

---

## Running with Docker Compose

**Build and start (foreground):**
```bash
docker compose up --build
```

**Build and start (detached):**
```bash
docker compose up --build -d
```

**Stop:**
```bash
docker compose down
```

**View logs:**
```bash
docker compose logs -f terraria
```

**Send a command to the server:**
```bash
docker exec terraria inject "say Message here"
docker exec terraria inject "save"
```

The container name is `terraria` by default. If you changed it, use that name instead of `terraria` in `docker exec`.

---

## Restart and changing settings

When you **restart** the container, the **existing world file is loaded as-is**. `TERRARIA_WORLDSIZE` is only used when **creating a new world** (no `.wld` file yet). So you can safely:

- Restart Docker and keep the same world.
- Change `TERRARIA_MOTD`, `TERRARIA_PASS`, `TERRARIA_MAXPLAYERS`, `TERRARIA_DIFFICULTY`, `TERRARIA_NPCSTREAM`, etc. on restart without affecting the existing world.
- Leave `TERRARIA_WORLDSIZE=3` even if the world was created as Large; the server only uses it for `-autocreate` when the world does not exist.

---

## Credits and links

- Terraria: [Official site](https://terraria.org/) | [Steam](https://store.steampowered.com/app/105600/Terraria/)
- Server config file (when using `TERRARIA_USECONFIGFILE=Yes`): [Terraria Wiki – Server config](https://terraria.fandom.com/wiki/Server#Server_config_file)
- Env/config reference: [PassiveLemon terraria-docker variables](https://github.com/PassiveLemon/terraria-docker/blob/master/terraria/scripts/variables.sh) (e.g. difficulty, npcstream). If `-difficulty`/`-npcstream` are not applied by your server binary, use `TERRARIA_USECONFIGFILE=Yes` and a `serverconfig.txt` with `difficulty=` and `npcstream=`.

This image is for hosting a Terraria server only. Terraria is the property of its respective owners; this project is not affiliated with and does not infringe on any copyright, trademark, or intellectual property.
