# Roadmap

Where the Shards server is going, and how far it has got. The direction is in [ADR 0001](adr/0001-server-direction.md).

Legend: ✅ done · 🔨 in progress · ⬜ not started

## Phase 1: Repo setup and running unchanged

- ✅ Git fork of upstream (`upstream` remote, `master` at `c7af53b0`, 2026-10-10)
- ✅ `AGENTS.md`, `CLAUDE.md`, `README.md`, ADR 0001, this roadmap
- ✅ Windows build (`nmake Bserver Bkod`, VS 2026 x86) and our run folder (`tools/setup-run.cmd` → `run/shards/`). Tested 2026-10-11: starts, answers the maintenance port, and reloads its save after `terminate save`.
- ✅ Linux build in Docker (`deploy/`). Tested 2026-10-11: starts, reloads its save across a restart and an image rebuild, and loads a save made by the Windows build.
- ✅ Shards config: ports 5960/9999, maintenance mask 127.0.0.1, MOTD (`config/`, `deploy/blakserv.cfg`), maintenance helpers (`tools/maint.ps1`, `deploy/maint.sh`)
- ✅ Upstream's Windows client builds (`tools\build.cmd Bclient Bmodules`) and is set up with Steam art plus our rooms and strings (`tools\setup-client.ps1`, 2026-10-11)
- ✅ Smoke test with that client (2026-10-11): an admin account created in the server window, logged in, character in the Raza Inn, account kept in the save
- ✅ `origin` remote on GitHub: [jboullion/meridian-shards-server](https://github.com/jboullion/meridian-shards-server)

## Phase 2: Protocol audit and client migration

Two rulesets, `original` and `shards`, and no `server104` ([ADR 0003](adr/0003-two-rulesets.md)).

- ✅ [protocol-dialect.md](protocol-dialect.md): `original` vs Server 104 audit (2026-10-11), now the clients' migration guide. Not done: a value-by-value audit of every enum Kod sends.
- ✅ The Shards protocol version announced at login: `AP_SHARDS_INFO = 60`, Shards protocol 1 ([ADR 0002](adr/0002-protocol-version.md), 2026-10-11). Checked with `tools/login-check.py` and upstream's Windows client, which ignores it.
- ⬜ Tag a last 104-capable release of each client (browser, Unreal) for play on Server 104 until Shards is hosted
- ⬜ Migrate each client from 104 to `original` (in the client repos), per the migration guide:
  - the packed object descriptor and flags, plus rarity
  - the player-list entry
  - `UC_SAFETY` instead of preferences
  - plain-string `UC_LOOK_PLAYER` fixed text
  - no skill school byte in `BP_CHARINFO`
  - list `BP_REQ_DROP` and WORD `BP_REQ_INVENTORY_MOVE`
  - no secret key in `AP_LOGIN`
  - `BP_REQ_GET_FROM_CONTAINER = 239`
  - RSC v4 and ROO v12/13 readers
  - school and stat-group values
  - then delete the 104-only paths
- ⬜ The `shards` ruleset in the clients: `original` plus version-gated changes, read from `AP_SHARDS_INFO`
- ⬜ Client data and assets from this server's build: rules, derived JSON (browser `roomlinks`/`itemslots`/`spelltimes`, Unreal `extract.py`), `rsc0000.rsb` and rooms
- ✅ Art: permission confirmed (2026-10-11), provided the client and server stay open source and the art is never committed to a repo
- ⬜ Gateway and `servers.json` point at the Shards server (port 5960)

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
- ⬜ Hosting: beside the 104 stack at first, with a gateway route and our own `/assets`. Then replace 104 as the browser's hosted world: a fresh world, announced to its players.
- ⬜ Branding: server name, MOTD, welcome text. Kod still says "new to the lands of Meridian 59" in player descriptions, and `help` points at upstream's web pages.

## Phase 4: Server 104 features, the Shards way (Shards v1.0)

104 is a design reference, not code to merge ([ADR 0003](adr/0003-two-rulesets.md)).

- ⬜ `server104-features.md`: a catalog of what 104 adds (Kod, the 36 extra built-ins, rooms); the user marks each feature keep or skip. Wanted so far:
  - weapon tiers (likely on upstream's existing rarity grade)
  - training points and unbound energy (ordinary `BP_STAT` lines in 104, so Kod-only)
- ⬜ Port each chosen feature:
  - Kod and existing messages first
  - protocol changes additive only and versioned in `protocol-dialect.md`
  - C built-ins only when Kod can't do it
- ⬜ Tag `v1.0`; new Shards features start here
- Known porting hurdles, found in the protocol audit:
  - **Comments:** 104 Kod uses `//` comments, which upstream's `bc` doesn't accept (`blakcomp/blakcomp.l:126-128` takes only `%`). Convert them while copying, or teach `bc` `//`.
  - **Rooms:** 104 rooms are `.roo` v15 (floating point), read by its own BSP loader (`blakserv/roofile.c`); ours are v12/13. Adopting v15 would be a client format change, so it needs an ADR.
  - **Resources:** 104 resources are RSC v5 (per-language strings); ours are v4. Same rule as rooms.
