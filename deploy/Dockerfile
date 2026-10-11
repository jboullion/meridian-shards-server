# Meridian: Shards server for Linux: blakserv plus the compiled Kod, built from this repo.
#
#   docker compose -f deploy/docker-compose.yml up -d --build
#
# Build context is the repo root (see docker-compose.yml); Dockerfile.dockerignore keeps
# Windows build output, run folders and git history out of it. The build uses upstream's
# Linux makefiles unchanged, the same steps as .github/workflows/c-cpp.yml.

FROM ubuntu:24.04 AS build
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends g++ make flex bison \
 && rm -rf /var/lib/apt/lists/*
COPY . /src
# The makefiles copy their output into run/server (loadkod, rsc) and bin (bc)
RUN mkdir -p /src/run/server/loadkod /src/run/server/rsc /src/bin
WORKDIR /src/blakcomp
# Not parallel: blakcomp/makefile.linux:33 (lexyy.c) can run before its debug/ folder exists
RUN make -f makefile.linux
WORKDIR /src/kod
RUN make -f makefile.linux
WORKDIR /src/blakserv
RUN make -f makefile.linux -j"$(nproc)"

FROM ubuntu:24.04
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends netcat-openbsd \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --home /srv/blakserv blakserv
WORKDIR /srv/blakserv
COPY --from=build /src/blakserv/debug/blakserv ./blakserv
COPY --from=build /src/run/server/loadkod/ ./loadkod/
COPY --from=build /src/run/server/rsc/ ./rsc/
COPY --from=build /src/kod/kodbase.txt ./kodbase.txt
COPY --from=build /src/kod/include/blakston.khd ./blakston.khd
COPY --from=build /src/resource/rooms/ ./rooms/
COPY --from=build /src/run/server/packages.txt ./packages.txt
COPY deploy/blakserv.cfg ./blakserv.cfg
COPY config/motd.txt ./motd.txt
COPY deploy/maint.sh /usr/local/bin/maint
# blakserv writes memmap (bof copies, the MOTD) at run time. banned.txt is the IP ban
# list (blakserv/loadall.c:41); an empty one avoids a startup error. It is not on a
# volume yet, so bans don't survive a new image (roadmap, Phase 3).
RUN chmod +x /usr/local/bin/maint \
 && mkdir -p savegame channel memmap && touch banned.txt \
 && chown -R blakserv:blakserv /srv/blakserv
USER blakserv

# Game state and logs live on volumes so a new image keeps the world
VOLUME ["/srv/blakserv/savegame", "/srv/blakserv/channel"]
# 5960: game (gateway and clients). 9999: maintenance, which stays inside the container
# (use `docker compose exec blakserv maint "<command>"`).
EXPOSE 5960
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s CMD nc -z 127.0.0.1 9999 || exit 1
# Upstream's Linux server runs in the foreground with no console (blakserv/osd_linux.c:126)
CMD ["./blakserv"]
