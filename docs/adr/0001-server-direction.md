# ADR 0001: Server direction

- Status: Accepted
- Date: 2026-10-10

## Context

We want our own server for **Meridian: Shards**: a modernized Meridian 59 that keeps its charm, and where we can add and remove features freely.

Our clients, [meridian-browser](E:\2026_Experiments\meridian-browser) and [meridian-unreal](E:\2026_Experiments\meridian-unreal), talk to an unmodified Server 104 today. We play and test on 104, and will keep doing so while the clients mature.

We looked at three things: whether to port the server to a new stack (Rust, Go, modern C++, an Unreal dedicated server, or a full rewrite), which codebase to start from, and how the clients should handle more than one server.

**What the code says:**

**The game is Kod, not C.**
- Upstream has about 29.5k lines of C against about 255k lines of Kod in 1,232 files.
- Combat, spells, monsters, items, guilds and the player all live in Kod, as do most outgoing packets (`AddPacket`).
- The C is a small bytecode VM (`blakserv/sendmsg.c`) plus 61 built-ins (`blakserv/ccode.c`), networking, saves and GC.

**Performance is ample.**
- The game is timer- and event-driven, with no per-frame simulation.
- It ran hundreds of players per server on 1990s hardware. A modern core handles far more than Shards will ever have.
- Kod's global state rules out multi-threading in any language, and we don't need it.

**Modifiability gaps are tooling, not architecture.**
- The gaps:
  - no types or tests
  - quiet runtime errors
  - 28-bit integers with no floats (`include/bkod.h:207`)
  - content written as code
  - whole-world snapshot saves
- All of them can be fixed in place with new built-ins, tools and save handling.
- The stack also has something most modern stacks lack: `reload system` reloads all Kod on a live server (`blakserv/adminfn.c:4318`).

**A rewrite costs the charm.** Kod holds every spell formula and monster quirk. Rewriting or transpiling it costs years, or drifts behaviour, for gains we can mostly get in place.

**Upstream and Server 104 compared:**

| | Upstream | Server 104 |
|---|---|---|
| C/C++ | ~29.5k lines | ~36.5k lines |
| Kod | ~255k lines | ~389k lines |
| Built-ins | 61 | 97 |
| State | C++20, epoll/kqueue, Linux and macOS CI | — |
| Maintenance | Still maintained | — |

The two share a lineage, so 104 features can be merged rather than re-implemented.

## Decision

1. **Same stack forever.** Shards runs `blakserv` and Kod. We do not port to Rust, Go or anything else, and we do not rewrite or transpile Kod. Gaps are fixed in place: new built-ins in `blakserv/ccode.c`, tools, and save and security work.
2. **Clean slate from upstream.** This repo is a git fork of [Meridian59/Meridian59](https://github.com/Meridian59/Meridian59) with `upstream` as a remote. We merge upstream fixes as they land, and keep our changes additive so merges stay cheap.
3. **Server 104 features come in as the first big upgrade (v1.0),** chosen one by one from a catalog (`docs/server104-features.md`). New Shards features come after that.
4. **Clients are not forked.** Each client gets a ruleset layer, `"original" | "server104" | "shards"`, picked per server in the login list.
   - `original` and `server104` are treated as frozen. A profile changes only if one of those teams changes their protocol.
   - `shards` evolves, and the server announces its protocol version at login.
   - [docs/protocol-dialect.md](../protocol-dialect.md) is the spec.

## Consequences

- Gameplay work can start as soon as the server runs: it is Kod work.
- We maintain about 30k lines of older C. Safety comes from small, reviewed changes and tests, not a rewrite.
- Every protocol-visible change needs a `protocol-dialect.md` entry and a matching client change under the `shards` ruleset.
- Clients carry three rulesets: one codec layer with per-feature switches, per-server assets, and per-ruleset derived data. The two frozen rulesets are one-time work.
- Contributors need to learn Kod. That is the one cost we can't remove.
- `kodbase.txt` stays a build output, as upstream has it. Saves store names, not ids (`blakserv/savegame.c:143-154`).

## Alternatives

- **Fork Server 104 instead of upstream:** rejected.
  - We want a clean slate and to add only the 104 features we like.
  - Upstream is smaller, cleaner and still maintained.
- **A new runtime in Rust or Go, keeping Kod:** rejected.
  - It means months of fidelity work (integer wrap, `Post` and timer order, GC renumbering, byte-exact protocol) for no gameplay gain.
  - 104's C features would have to be re-implemented instead of merged.
  - Upstream fixes would stop flowing in.
- **Modern C++ rewrite:** rejected. Upstream is already C++20, and we can modernize it piece by piece.
- **Unreal dedicated server:** rejected.
  - It drops the blakserv protocol, which breaks the browser client.
  - All Kod would have to be rewritten.
  - It is heavyweight to host.
  - The Epic EULA conflicts with GPLv2 Meridian code.
- **A full new game (new engine and logic):** not now. Revisit only if Shards changes the game model itself: true 3D worlds with server-side 3D collision, real-time action combat, or mainstream-language modding as a core goal.
- **Transpile Kod to Lua or TypeScript:** rejected. It is a large compiler project for tooling gains we can mostly get otherwise, and it would make merging 104 Kod painful.
- **Fork the clients per server:** rejected in favour of rulesets in one codebase per client.
