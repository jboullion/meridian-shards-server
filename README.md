# Meridian: Shards server

Our own Meridian 59 server, built to keep the game's charm while we modernize it. It is a git fork of the original upstream game, [Meridian59/Meridian59](https://github.com/Meridian59/Meridian59), on the same stack: `blakserv` (C++20) running the Blakod game scripts. Upstream's own readme is [`README`](README).

- **Why this shape:** [docs/adr/0001-server-direction.md](docs/adr/0001-server-direction.md)
- **Where it's going:** [docs/roadmap.md](docs/roadmap.md)
- **What clients must know:** [docs/protocol-dialect.md](docs/protocol-dialect.md) (the `shards` ruleset vs `original` and `server104`)
- **For contributors and AI agents:** [AGENTS.md](AGENTS.md)

Meridian 59 is © Andrew Kirmse and Chris Kirmse, and "Meridian" is their registered trademark. This project is unaffiliated. The code is GPLv2 (see [`LICENSE`](LICENSE)). Game art, rooms and audio are not covered by that licence.

## Run it on Windows

You need Visual Studio 2026 with the C++ tools. From an "x86 Native Tools Command Prompt for VS 2026":

```bat
nmake Bserver Bkod
tools\setup-run.cmd
cd run\shards
..\server\blakserv.exe
```

- `nmake Bserver Bkod` builds the server and the Kod into upstream's `run\server`.
- `tools\setup-run.cmd` makes our run folder, `run\shards` (git-ignored), with `config\blakserv.cfg` and `config\motd.txt`. Saves and logs live there.
- The game listens on port **5960** and maintenance on **9999** (localhost only), so a Server 104 can run beside it on 5959/9998.
- The first start builds a fresh world, which takes a few seconds.

Create your admin account in the server window's **Administration** tab:

```
create account admin <name> <password>
create admin <account id from the reply>
save game
```

Send maintenance commands from PowerShell:

```powershell
powershell -File tools\maint.ps1 "show status" "who"
powershell -File tools\maint.ps1 "terminate save"   # save and shut down
```

After changing Kod, run `nmake Bkod`, then `reload system` on the maintenance port. That saves and reloads all Kod without a restart.

## Run it on Linux (Docker)

```bash
docker compose -f deploy/docker-compose.yml up -d --build
docker compose -f deploy/docker-compose.yml exec blakserv maint "show status"
docker compose -f deploy/docker-compose.yml exec blakserv maint "terminate save"   # save and shut down
```

- The image builds blakserv and the Kod with upstream's Linux makefiles. Saves and logs are on the `savegame` and `channel` volumes, so a rebuilt image keeps the world.
- Always shut down with `terminate save`. `docker stop` loses everything since the last save, because blakserv doesn't handle SIGTERM yet.
- Upstream's Linux server has no admin console, and the maintenance port can't create accounts. Until that's fixed (roadmap, Phase 3), create accounts on a Windows run and copy its `savegame` folder into the volume.

## Pulling upstream fixes

```bash
git fetch upstream
git merge upstream/master
```

Our changes are kept additive (new files under `config/`, `deploy/`, `tools/`, `docs/`) so these merges stay easy.
