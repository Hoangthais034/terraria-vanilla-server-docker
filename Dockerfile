# Build args (e.g. TERRARIA_VERSION) are passed from .env via docker-compose build args.
FROM ubuntu:24.04

ARG TERRARIA_VERSION

EXPOSE 7777

# Install runtime deps and clean apt in one layer
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget unzip tmux ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/terraria-server

# Download and extract Terraria dedicated server (single layer for smaller image)
RUN wget -q "https://terraria.org/api/download/pc-dedicated-server/terraria-server-${TERRARIA_VERSION}.zip" -O server.zip \
    && unzip -o server.zip \
    && rm server.zip

RUN mkdir -p /root/.local/share/Terraria/Worlds

# Default: use config file generated from env (no need to create serverconfig.txt by hand)
ENV TERRARIA_USECONFIGFILE=Yes
ENV TERRARIA_GENERATE_FROM_ENV=Yes

COPY entrypoint.sh autosave.sh generate-serverconfig.sh ./
COPY inject.sh /usr/local/bin/inject

RUN chmod +x entrypoint.sh autosave.sh generate-serverconfig.sh /usr/local/bin/inject \
    && chmod +x "/root/terraria-server/${TERRARIA_VERSION}/Linux/TerrariaServer.bin.x86_64"

ENTRYPOINT ["./entrypoint.sh"]
