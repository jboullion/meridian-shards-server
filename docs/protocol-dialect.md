# Protocol dialects

This file is the spec for the clients' three rulesets:
- `original`: this repo's upstream code, unmodified.
- `server104`: Server 104, the fan fork our clients play on today.
- `shards`: this server.

`original` and `server104` are treated as frozen. `shards` changes, and each change is listed below with the Shards protocol version that introduced it.

Status: **seeded, audit not done** (Phase 2 in the [roadmap](roadmap.md)). Facts marked *checked* were read from both trees. Paths are relative to each tree's root. The 104 tree is `E:\2026_Experiments\meridian-unreal\ReferenceServers\Server-104`.

## Message ids

From `include/proto.h` in both trees, *checked* 2026-10-10. Upstream defines 179 ids and 104 defines 189.

| Message | `original` | `server104` |
|---|---|---|
| `AP_CLIENT_PATCH_OLD` | — | 12 |
| `AP_CLIENT_PATCH` | — | 13 |
| `BP_AD_SELECTED` | — | 24 |
| `BP_DELETE_NEWS` | — | 84 |
| `BP_REQ_STAT_CHANGE` | — | 156 |
| `BP_CHANGED_STATS` | — | 157 |
| `BP_CHANGED_STATS_OK` | — | 158 |
| `BP_STOP_WAVE` | — | 173 |
| `BP_RADIUS_SHOOT` | — | 229 |
| `BP_SECTOR_CHANGE` | — | 239 |
| `BP_REQ_GET_FROM_CONTAINER` | **239** | **240** |

All other ids match.

## Payload layouts

Packets are mostly built in Kod with `AddPacket`, so layouts can differ even where ids match.

- **Object descriptor** (`ToCliObject` in `kod/object/active/holder/nomoveon/battler/player/user.kod`), *checked*:
  - `original` packs the drawing effect (`DRAWFX_*`) into the object flags (`user.kod:2354`).
  - `server104` sends drawing effects separately from the object flags (`GetDrawingEffects`), and adds minimap flags (`user.kod:3140`).
  - Almost every world packet carries this descriptor.
- **To audit:**
  - Player, stats, spells and skills, look/description, room contents, enchantments, inventory, trade, mail, guilds and minigames.
  - The C-side packets: `blakserv/synched.c` (login, file info), the `blakserv/game.c` header and CRC stream, and the `blakserv/commcli.c` redbook token.

## Login

- **To audit:** the client version numbers each server accepts (`[Login] MinVersion`/`InvalidVersion` in `blakserv/config.c`) and resync behaviour.
- `server104` has a `SecretKey` setting that the client must match. `original` has none.

## Shards changes

None yet. The Shards protocol version is 0, which means identical to `original`.
