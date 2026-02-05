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
| `TERRARIA_WORLDSIZE` | `3` | `1` = Small, `2` = Medium, `3` = Large. Used when creating a new world. |
| `TERRARIA_WORLDSEED` | `Docker` | Any string. Seed for new world generation. |
| `TERRARIA_USECONFIGFILE` | `No` | `Yes` or `No`. If `Yes`, server uses a config file (must be mounted; see Terraria server docs). |
| `TERRARIA_PORT` | `7777` | Host port to publish. Container always listens on 7777. |
| `TERRARIA_DATA_PATH` | `./terraria-data` | Host path for world data (direct bind mount). Relative or absolute. |

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

## Credits and links

- Terraria: [Official site](https://terraria.org/) | [Steam](https://store.steampowered.com/app/105600/Terraria/)
- Server config file (when using `TERRARIA_USECONFIGFILE=Yes`): [Terraria Wiki – Server config](https://terraria.fandom.com/wiki/Server#Server_config_file)

This image is for hosting a Terraria server only. Terraria is the property of its respective owners; this project is not affiliated with and does not infringe on any copyright, trademark, or intellectual property.
