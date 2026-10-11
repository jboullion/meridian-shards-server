# Roadmap

Where the Shards server is going, and how far it has got. The direction is in [ADR 0001](adr/0001-server-direction.md).

Legend: ✅ done · 🔨 in progress · ⬜ not started

## Phase 1: Repo setup and running unchanged

- ✅ Git fork of upstream (`upstream` remote, `master` at `c7af53b0`, 2026-10-10)
- ✅ `AGENTS.md`, `CLAUDE.md`, `README.md`, ADR 0001, this roadmap
- ✅ Windows build (`nmake Bserver Bkod`, VS 2026 x86) and our run folder (`tools/setup-run.cmd` → `run/shards/`). Tested 2026-10-11: starts, answers the maintenance port, and reloads its save after `terminate save`.
- ✅ Linux build in Docker (`deploy/`). Tested 2026-10-11: starts, reloads its save across a restart and an image rebuild, and loads a save made by the Windows build.
- ✅ Shards config: ports 5960/9999, maintenance mask 127.0.0.1, MOTD (`config/`, `deploy/blakserv.cfg`), maintenance helpers (`tools/maint.ps1`, `deploy/maint.sh`)
- ⬜ Smoke test with upstream's Windows client (`clientd3d`), done by the user:
  - build it with `nmake Bclient Bmodules`, which also makes `rsc0000.rsb`
  - it needs the game art from elsewhere
  - log in, create a character and walk
- ⬜ `origin` remote on GitHub (the user creates it and pushes)

## Phase 2: Protocol audit and client rulesets

- ⬜ [protocol-dialect.md](protocol-dialect.md): full `original` vs `server104` audit. It covers message ids, every differing `AddPacket` site, the C-side packets (`synched.c`, `game.c`, `commcli.c`), client versions and resync behaviour.
- ⬜ The Shards protocol version announced at login (ADR)
- ⬜ Client ruleset layer (in the client repos):
  - The `server104` profile first, with no behaviour change
  - Then `original`, then `shards`
- ⬜ Per-ruleset data in the clients (rules, derived JSON) and per-server asset namespaces
- ⬜ Gateway: per-server targets (`/ws/104`, `/ws/shards`); `servers.json` entries carry a `ruleset`

## Phase 3: Clean-slate modernization (Shards v0.x)

- ⬜ Remove the hardcoded admin accounts in `blakserv/builtin.c`
- ⬜ A way to create accounts and admins on Linux. Today only the Windows admin window can: the maintenance port can't run `create` (`blakserv/adminfn.c:509`), and Linux has no console (`blakserv/osd_linux.c:126`). For example, allow `create account` from localhost maintenance sessions.
- ⬜ Save and exit on SIGTERM, so `docker stop` is safe (no handler in `blakserv/osd_epoll.c`)
- ⬜ Put `banned.txt` (the IP ban list, `blakserv/loadall.c:41`) on a volume, so bans survive a new image
- ⬜ Fix the inverted check in `blakserv/motd.c:46` (it logs an error when `rename()` succeeds), and offer it upstream
- ⬜ Fix the `blakcomp/makefile.linux` parallel-build race (`lexyy.c` before `debug/` exists), and offer it upstream
- ⬜ Password storage: argon2/bcrypt over the client's MD5, migrated on login (ADR)
- ⬜ Saves: atomic writes, rotating backups, shorter `SavePeriod`
- ⬜ Logs to stdout under Docker; Kod runtime errors counted and shown on the maintenance port
- ⬜ Kod test harness in `tools/testbench/` (adapted from the 104 `claude-testbench`), plus a smoke test
- ⬜ CI: Docker build plus smoke test, beside upstream's `c-cpp.yml`
- ⬜ Hosting beside the 104 stack, with a gateway route and our own `/assets`
- ⬜ Branding: server name, MOTD, welcome text

## Phase 4: The Server 104 upgrade (Shards v1.0)

- ⬜ `server104-features.md`: a catalog of what 104 adds (Kod, the 36 extra built-ins, rooms); the user marks each feature keep or skip
- ⬜ Port the chosen features one at a time: built-ins, then Kod, then rooms and resources; update `protocol-dialect.md` and the clients' `shards` profile
- ⬜ Tag `v1.0`; new Shards features start here
