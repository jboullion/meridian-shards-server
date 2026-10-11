# AGENTS.md

Guidance for AI coding agents (and humans who like the detail) working in this repo.

## What this is

**Meridian: Shards** is our own Meridian 59 server: a git fork of the original upstream game, [Meridian59/Meridian59](https://github.com/Meridian59/Meridian59). It keeps the same stack forever: `blakserv` (C compiled as C++20) runs the Blakod (Kod) game scripts.

- **Direction and why:** [docs/adr/0001-server-direction.md](docs/adr/0001-server-direction.md)
- **Phases and progress:** [docs/roadmap.md](docs/roadmap.md)
- **Running it:** [README.md](README.md) (ours) and `README` (upstream's)
- **Clients:** [meridian-browser](E:\2026_Experiments\meridian-browser) and [meridian-unreal](E:\2026_Experiments\meridian-unreal) talk to this server through their `shards` ruleset. They also keep `server104` and `original` rulesets for other codebases.

## Hard rules

- **The name is "Meridian: Shards".**
  - Never use "104" in any product name, branding or in-game text. Referring to the "Server 104" *code* in docs is fine.
  - "Meridian" is the Kirmses' trademark; don't brand anything as theirs.
- **Licence:** GPLv2 with the original `wrap.dll`/`waveplay.dll` exception (`LICENSE`). Keep it.
- **Same stack forever.** No ports to another language and no Kod rewrite (ADR 0001). New behaviour goes in Kod, plus C built-ins in `blakserv/ccode.c` when Kod can't do it.
- **Keep upstream merges cheap:**
  - Prefer new files over edits to upstream files.
  - When an upstream file must change, keep the diff small: no reformatting, no renames, no moving code. Leave an `// Shards:` comment where the reason isn't obvious.
  - Our own files live in `config/`, `deploy/`, `tools/` and `docs/` (ADRs, roadmap, protocol notes).
  - Pull upstream with `git fetch upstream && git merge upstream/master`.
- **Every protocol-visible change goes in [docs/protocol-dialect.md](docs/protocol-dialect.md).** That covers message ids and packet layouts, including `AddPacket` changes in Kod. It is the clients' spec for the `shards` ruleset. Bump the Shards protocol version when it changes.
- **Decisions go in ADRs** (`docs/adr/NNNN-title.md`) with Status, Date, Context, Decision, Consequences and Alternatives sections. Strike out superseded decisions with a "Changed <date>" note.
- **No new raw art in git:** `.bgf`, `.roo`, `.rsb`, `.ogg`, `.wav`, `.bmp`, extracted PNGs. Upstream already tracks its own rooms and bitmaps; leave those as they are. New art for Shards is served from the asset build.
- **The user makes the commits.** Don't `git commit` or push unless explicitly asked. Finish by listing the changed files.
- **Ask before downloading or installing anything** (packages, tools, images, client builds), stating what it is, the source and the size.
- **Reference trees are read-only:**
  - `E:\2026_Experiments\meridian-unreal\ReferenceServers\Server-104` (Server 104)
  - the client repos
- **Own servers only.** Never point a tool at a live server you don't run.

## Repo layout

Upstream's layout is unchanged. The parts that matter for the server:

| Path | What it holds |
|---|---|
| `blakserv/` | The server: VM (`sendmsg.c`), built-ins (`ccode.c`), sessions and protocol (`session.c`, `synched.c`, `game.c`, `commcli.c`), saves (`saveall.c`, `savegame.c`), GC (`garbage.c`), admin commands (`adminfn.c`). |
| `blakcomp/` | `bc`, the Kod compiler (flex/bison). Writes `.bof`, `.rsc` and `kodbase.txt`. |
| `kod/` | The game, about 255k lines of Kod. `kod/include/blakston.khd` holds the constants; `protocol.khd` the message ids Kod sends. |
| `include/proto.h` | `AP_*` and `BP_*` message ids shared by client and server. |
| `resource/rooms/` | Upstream's `.roo` rooms (the server reads them for movement). |
| `run/server/` | Upstream's run folder. The build copies `blakserv.exe`, `.bof` and `.rsc` files here. |
| `clientd3d/` | Upstream's Windows client: the reference client for the `original` and `shards` rulesets. |
| `doc/` | Upstream's design docs: `bkod.txt`, `bof.txt`, `protocol.txt`, `login.txt`, `blakod.tex`. |

Ours:

| Path | What it holds |
|---|---|
| `config/blakserv.cfg`, `config/motd.txt` | Our server config and message of the day for a Windows run. |
| `tools/setup-run.cmd` | Creates `run/shards/` (git-ignored), our run folder. It reuses `run/server`'s binary, code and resources, and keeps its own config, saves and logs. |
| `tools/maint.ps1` | Sends one command to the maintenance port. |
| `deploy/` | The Linux build and hosting: `Dockerfile` (+ `Dockerfile.dockerignore`), `docker-compose.yml`, `blakserv.cfg` (forward slashes), `maint.sh` (installed as `maint` in the image). |
| `docs/` | ADRs, the roadmap, `protocol-dialect.md`. Upstream's `webhooks.md`, `audio.md` and `themes.md` live here too. |

## Building and running

```bat
:: Windows: from an "x86 Native Tools Command Prompt for VS 2026" (or after vcvars32.bat)
nmake Bserver Bkod
tools\setup-run.cmd
cd run\shards && ..\server\blakserv.exe
```

```bash
# Linux in Docker (game on 5960; maintenance stays inside the container)
docker compose -f deploy/docker-compose.yml up -d --build
docker compose -f deploy/docker-compose.yml exec blakserv maint "who"
```

- **Ports:** game 5960 and maintenance 9999, so Shards runs beside a Server 104 on 5959/9998.
- **Maintenance commands end with CR.** `tools\maint.ps1 "show status"` handles that.
- **Shut down with `terminate save`.** It saves, then exits.
  - blakserv has no SIGTERM handler, so `docker stop` or killing the process loses everything since the last save.
  - The compose file restarts only on failure, so a clean `terminate save` stays down.
- **First admin account:** in the Windows server window's Administration tab, run `create account admin <name> <password>`, then `create admin <account id>`, then `save game`.
  - The maintenance port can't run `create` (the commands are admin-only, `blakserv/adminfn.c:509`), and upstream's Linux build has no console.
  - On Linux, copy a Windows run's `savegame/` into the volume. Saves load across the two builds (tested 2026-10-11).

## Known traps

- **`kodbase.txt` is a build output** (upstream git-ignores it). Saves store class and property *names* (`blakserv/savegame.c:143-154`), so rebuilding it doesn't break saves.
- **`run/server/blakserv.cfg` is upstream's file.** Don't edit it; ours is `config/blakserv.cfg`.
- **Linux file names are case-sensitive.** Upstream's Kod room names match `resource/rooms/` exactly (checked 2026-10-10), unlike Server 104's. Keep it that way when adding rooms.
- **"LoadMotd can't move motd.txt" in `error.txt` is harmless.** `blakserv/motd.c:46` reports an error when `rename()` *succeeds*; the MOTD does move into `memmap/`.
- **Parallel make breaks `blakcomp` on Linux:** `blakcomp/makefile.linux:33` can run before `debug/` exists, so the Dockerfile builds it without `-j`.
- **The client's `rsc0000.rsb`** (built by `rscmerge` on Windows) must come from the same Kod build the server runs. The redbook token and every name the client shows depend on it.
- **Saves renumber object ids** (`garbage.c` runs before every save). Clients see this as `BP_INVALIDATE_DATA`.
- **Kod integers are 28-bit signed** (`include/bkod.h:207`); there are no floats.
- **`reload system`** (maintenance or admin) saves, then reloads every `.bof` live. Use it after a Kod rebuild instead of restarting.

## Writing docs

Plain and concrete:
- Short sentences.
- Real paths and commands.
- The reason in a clause.
- Cite C and Kod as `file:line`.
