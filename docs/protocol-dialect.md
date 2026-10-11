# Protocol dialects

The clients have two rulesets ([ADR 0003](adr/0003-two-rulesets.md)):
- `original`: this repo's upstream code, unmodified. Frozen.
- `shards`: this server. It starts identical to `original`. Each later change is additive and listed under [Shards changes](#shards-changes) with the Shards protocol version that introduced it. The server announces that version at login ([ADR 0002](adr/0002-protocol-version.md)).

Today's clients speak the **Server 104** dialect, so this file also serves as their **migration guide**: every place where `original` differs from 104. In the tables, the `server104` column is what a client does today, and the `original` column is what it must do instead. There is no `server104` ruleset to keep. After migrating, the 104-only code paths are deleted (tag a last 104-capable client release first).

The 104 wire format is documented in the client repos:
- `meridian-browser/docs/research/protocol.md`
- `meridian-unreal/docs/research/blakserv-protocol.md`

**Status:** audited 2026-10-11 against upstream `master` (`c7af53b0`) and the 104 tree at `E:\2026_Experiments\meridian-unreal\ReferenceServers\Server-104`.

**Paths:**
- `u:` is this repo.
- `s:` is the 104 tree.
- Line numbers are from those checkouts.

## How this was audited

Each tree ships a Windows client that matches its own server, so the two clients' parsers are the ground truth for each dialect. The audit:

1. **Diffed `include/proto.h` and `kod/include/protocol.khd`:** every message id, user-command id and flag constant.
2. **Compared every message handler function by name** in `clientd3d/server.c`, `clientd3d/srvrstr.c` and the modules (`module/*/*.c`), ignoring whitespace, comments and `Bool`/`bool`-style spelling. 14 functions in `server.c` really differ, and five handlers exist only in 104.
3. **Compared the outgoing request tables** (`clientd3d/protocol.c` and the modules' `user_msg_table`s).
4. **Compared the server's login, framing and packet code:** `blakserv/synched.c`, `game.c`, `commcli.c`, `session.c`, `trysync.c`, `resync.c`.
5. **Compared the file formats the clients read:** `.rsb`/`.rsc` (`util/rscload.c`) and `.roo` (`clientd3d/bspload.c`).
6. **Spot-checked the Kod side** for values whose *meaning* differs inside unchanged layouts: schools, stat groups, effects.

**Not covered:** a value-by-value audit of every enum Kod sends (animation ids, sound flags, sector flags). Treat a value that only one tree's Kod uses as a possible difference, and check the Kod before relying on it.

## Summary: what a 104 client must change

Read each row as "today (`server104`) → after migrating (`original`)".

| Item | `original` (target) | `server104` (today) | Details |
|---|---|---|---|
| Client version sent in `AP_LOGIN` | any ≥ 1.00 (upstream's client is 7.37) | major 50 (classic) or 90 (Ogre); older minors get patched | [Login](#login) |
| `AP_LOGIN` secret key | none: the message ends after the password | a third string, which must equal the server's `SecretKey` | [Login](#login) |
| Unknown account name | `AP_LOGINFAILED` | account created automatically | [Login](#login) |
| Object descriptor | `flags` (packed) + `rarity` | `flags` + `drawingtype` + `minimapflags` + `namecolor` + `objecttype` + `moveontype` | [Objects](#object-descriptor) |
| Object flag bits | moveon, player type and draw effect packed into `flags` | each in its own field | [Flags](#object-flags) |
| Player list entry (`BP_PLAYERS`, `BP_PLAYER_ADD`) | id, name rsc, name, flags | same + the five 104 fields | [Players](#player-list-entries) |
| User command ids (`UC_*`) | `UC_SAFETY = 7` | `UC_REQ_PREFERENCES = 7`, `UC_SEND_PREFERENCES = 9`, `UC_RECEIVE_PREFERENCES = 34`, `UC_REQ_TIME = 60` | [User commands](#user-commands) |
| Safety | `UC_SAFETY` + byte | the `CF_SAFETY_OFF` bit of the preferences int | [User commands](#user-commands) |
| `UC_LOOK_PLAYER` "fixed" text | a plain string | a resource id + parameters | [Look player](#uc_look_player) |
| `BP_CHARINFO` skill entries | name, cost | name, cost, school byte | [Character creation](#character-creation-bp_charinfo) |
| `BP_REQ_DROP` | object list | one object | [Requests](#client-requests) |
| `BP_REQ_INVENTORY_MOVE` | two WORDs | two object ids | [Requests](#client-requests) |
| Extra server messages | — | `BP_SECTOR_CHANGE`, `BP_RADIUS_SHOOT`, `BP_STOP_WAVE`, `AP_CLIENT_PATCH(_OLD)`, `AP_GUEST` | [Ids](#message-ids) |
| `.rsb`/`.rsc` format | RSC version 4 | RSC version 5 (per-language strings) | [Files](#file-formats) |
| `.roo` format | versions 12–13 | version 15 (floating point) | [Files](#file-formats) |
| Spell/skill school numbers | no `SS_CRAFTING`; `SKS_TELEPATHY = 12`, `SKS_THIEVERY = 13` | `SS_CRAFTING = 7`; `SKS_THIEVERY = 12` | [Values](#values-that-differ-inside-unchanged-layouts) |
| Server text formatting | `%d %i %s %q %%` | adds `%r` and positional `$N` | [Text](#server-text-formatting) (104's formatter reads both) |
| Framing, CRC/LCG stream, redbook token, epoch | same | same | [Same](#what-is-the-same) |

## Login

**`AP_LOGIN`** (client → server):
- Both send the same 39 fixed bytes (versions, sysinfo), then the username and password as length-prefixed strings.
- 104 adds a third string, the secret key (`s:clientd3d/protocol.h:47`, `s:clientd3d/login.c-example:66`).
- The 104 server reads it and hangs up on a mismatch (`s:blakserv/synched.c:228-233`).
- The upstream server never reads past the password (`u:blakserv/synched.c:124`). It is not known yet whether a trailing third string is harmless there; a client should send none for `original`.

**Accounts:**
- 104 creates an account for an unknown name on its first login, with the configured number of character slots (`s:blakserv/synched.c:366`).
- Upstream answers `AP_LOGINFAILED` (`u:blakserv/synched.c:321`). Accounts are made by an admin, see the [README](../README.md).

**Client version:**
- Upstream compares `major*100 + minor` with `[Login] MinVersion` and `InvalidVersion` (default 100), and sends `AP_GETCLIENT` when it is too old (`u:blakserv/synched.c:434`).
- 104 gates on major 50/90 and on the client's `rsc0000.rsb` MD5, and patches with `AP_CLIENT_PATCH` (`s:blakserv/synched.c:518`).
- Upstream's client is 7.37 (`u:clientd3d/client.h:49`); 104's is 50.55 (`s:clientd3d/client.h:52`).
- Any version ≥ 1.00 passes upstream's defaults.

**`AP_REGISTER` and `AP_ADMINNOTE`** still work upstream (they append to files). 104 rejects them.

**`AP_LOGINOK`** is the same in both: one account-type byte.

## Object descriptor

Read by `ExtractObject` (`u:clientd3d/server.c:319`, `s:clientd3d/server.c:324`). It is used by:
- `BP_CREATE`, `BP_CHANGE`, `BP_LOOK`
- `BP_OBJECT_CONTENTS`, `BP_ROOM_CONTENTS`, `BP_INVENTORY`, `BP_INVENTORY_ADD`
- `BP_BUY_LIST`, `BP_WITHDRAWAL_LIST`
- `BP_OFFER`, `BP_OFFERED`, `BP_COUNTEROFFER`, `BP_COUNTEROFFERED`
- `BP_SPELLS`, `BP_SPELL_ADD`, `BP_SKILLS`, `BP_SKILL_ADD`, `BP_ADD_ENCHANTMENT`
- `UC_LOOK_PLAYER`, the newsgroup look message
- `BP_PLAYER_OVERLAY` (without the lighting block)

| `original` | `server104` |
|---|---|
| id (4) | id (4) |
| amount (4), only for number objects | amount (4), only for number objects |
| icon rsc (4) | icon rsc (4) |
| name rsc (4) | name rsc (4) |
| flags (4): see [Object flags](#object-flags) | flags (4): see [Object flags](#object-flags) |
| **rarity (4)**: `item_rarity_grade` | **drawingtype (1)**: `DRAWFX_*`, 0–255 |
| | **minimapflags (4)**: `MM_*` bits |
| | **namecolor (4)**: RGB, `NC_*` |
| | **objecttype (1)**: `OT_*` |
| | **moveontype (1)**: `MOVEON_*` |
| lighting block, unless "no light" | lighting block, unless "no light" |
| palette translation / effect | palette translation / effect |
| animation | animation |
| overlays | overlays |

The lighting, translation, animation and overlay blocks are byte-identical in both (`ExtractDLighting`, `ExtractPaletteTranslation`, `ExtractAnimation` and `ExtractOverlays` are unchanged). So `original` is 4 bytes after `flags`, and `server104` is 11.

**Kod side:** `ToCliObject` in `kod/object/active/holder/nomoveon/battler/player/user.kod` builds the descriptor (`u:…/user.kod:2324`, `s:…/user.kod:3111`).

**Rarity values** (`u:include/proto.h:497`):

| Grade | Value |
|---|---|
| normal | 0 |
| uncommon | 1 |
| rare | 2 |
| legendary | 4 |
| unidentified | 100 |
| cursed | 200 |

Upstream's client also shows rarity in descriptions (`DisplayDescription(…, obj.rarity)`).

## Object flags

`original` packs four things into `flags` (`u:include/proto.h:357-411`):

| Bits | `original` meaning | `server104` equivalent |
|---|---|---|
| `0x00000003` | `OF_NOMOVEON_MASK`: `OF_MOVEON_YES/NO/TELEPORTER/NOTIFY` (0–3) | the `moveontype` byte (`MOVEON_*`, same values). In 104, bits 0–1 are `OF_DISPLAY_NAME` and `OF_SIGN` instead. |
| `0x00000004` | `OF_PLAYER` | same |
| `0x00000008` | `OF_ATTACKABLE` | same |
| `0x00000010` | `OF_GETTABLE` | same |
| `0x00000020` | `OF_CONTAINER` | same |
| `0x00000040` | `OF_NOEXAMINE` | same |
| `0x00000080` | — | `OF_ITEM_MAGIC` |
| `0x00000100` | — | `OF_HANGING` |
| `0x00000200` | `OF_OFFERABLE` | same |
| `0x00000400` | `OF_BUYABLE` | same |
| `0x00000800` | `OF_ACTIVATABLE`; also `OF_FALSEPLAYER` when combined with `OF_PLAYER` | `OF_ACTIVATABLE` |
| `0x00001000` | `OF_APPLYABLE` | same |
| `0x00002000` | `OF_SAFETY` (self only) | `OF_NPC`. Safety is the preferences `CF_SAFETY_OFF` bit. |
| `0x0001C000` | `OF_PLAYER_MASK`: `PF_KILLER 0x4000`, `PF_OUTLAW 0x8000`, `PF_DM 0xC000`, `PF_CREATOR 0x10000`, `PF_SUPER 0x14000`, `PF_EVENTCHAR 0x1C000` | the `objecttype` byte (`OT_KILLER 1` … `OT_EVENTCHAR 7`, plus `OT_MODERATOR 6`), and `namecolor` for the colour |
| `0x00010000` | also `OF_HANGING` when not a player (overlaps `PF_CREATOR`) | `OF_BOUNCING` |
| `0x00020000` | `OF_FLICKERING` | same |
| `0x00040000` | `OF_FLASHING` | same |
| `0x00060000` | both bits set = `OF_BOUNCING` | — (bouncing is `0x10000`) |
| `0x00080000` | `OF_PHASING` | same |
| `0x01F00000` | `OF_EFFECT_MASK`: draw effect index × `0x100000`, 0–31 (`OF_TRANSLUCENT25` = 1 … `OF_SECONDTRANS` = 10) | the `drawingtype` byte (`DRAWFX_*`, same numbers 0–10, plus `DRAWFX_DITHERGREY = 0x0B`) |
| `0x02000000` | `OF_ENEMY` | `MM_ENEMY` in `minimapflags` |
| `0x04000000` | `OF_FRIEND` | `MM_FRIEND` |
| `0x08000000` | `OF_GUILDMATE` | `MM_GUILDMATE` |

**Name colour:** `original` has no name-colour field; the client derives the colour from the player-type bits. `server104` sends RGB in `namecolor`.

**Minimap:** `original` has no minimap bitfield; the client derives dots from `OF_PLAYER`, `OF_ENEMY`, `OF_FRIEND`, `OF_GUILDMATE` and `OF_ATTACKABLE`.

**Clean mapping:** a client can turn an `original` descriptor into its 104-shaped model, or the other way round, at decode time:

| 104 field | Taken from `original` |
|---|---|
| `moveontype` | `flags & 3` |
| `objecttype` | the player-type bits |
| `drawingtype` | `(flags & 0x01F00000) >> 20` |
| minimap bits | `OF_ENEMY` / `OF_FRIEND` / `OF_GUILDMATE` |

**Kod side:** `GetObjectFlags` in each tree builds `flags`. 104 adds `GetDrawingEffects` and friends (`u:…/user.kod:2354` vs `s:…/user.kod:3140`).

## Player list entries

`BP_PLAYERS` (each entry) and `BP_PLAYER_ADD` (`u:clientd3d/server.c:1090,1130`; `s:clientd3d/server.c:1150,1203`):

| `original` | `server104` adds after `flags` |
|---|---|
| id (4) | drawingtype (1) |
| name rsc (4) | minimapflags (4) |
| name (string) | namecolor (4) |
| flags (4) | objecttype (1) |
| | moveontype (1) |

## User commands

`BP_USERCOMMAND` sub-ids (`u:include/proto.h:223-`, `s:include/proto.h:232-`):

| Id | `original` | `server104` |
|---|---|---|
| 7 | `UC_SAFETY`: client → server, one byte, 1 = safety on (`u:module/merintr/merintr.c:92`, `SendConfiguredSafety` in `mermain.c`) | `UC_REQ_PREFERENCES`: client → server, no payload |
| 9 | — | `UC_SEND_PREFERENCES`: client → server, int of `CF_*` bits |
| 34 | — | `UC_RECEIVE_PREFERENCES`: server → client, int of `CF_*` bits (`s:module/merintr/merintr.c:1609`) |
| 60 | — | `UC_REQ_TIME`: client → server, no payload |

All other `UC_*` ids match.

`CF_*` bits (104 only): `CF_SAFETY_OFF 1`, `CF_TEMPSAFE 2`, `CF_GROUPING 4`, `CF_AUTOLOOT 8`, `CF_AUTOCOMBINE 0x10`, `CF_BAGS 0x20`, `CF_SPELLPOWER 0x40`. `original` has only safety.

### `UC_LOOK_PLAYER`

`u:module/merintr/merintr.c:1453`, `s:module/merintr/merintr.c:1534`.

| `original` | `server104` |
|---|---|
| object descriptor | object descriptor |
| flags (1) | flags (1) |
| description: rsc id + params | description: rsc id + params |
| **fixed text: one length-prefixed string** | **fixed text: rsc id (4) + params, formatted like any server message** |
| url: string | url: string; nothing may follow |

## Character creation (`BP_CHARINFO`)

`u:module/char/char.c:146`, `s:module/char/char.c:148`.

- Spell entries are the same in both: name rsc, cost (4), school (1).
- Skill entries are name rsc, cost (4) in `original`. `server104` adds a **school byte (1)**.
- `BP_CHARACTERS` is the same apart from cosmetics.
- `BP_AD_SELECTED` (client → server, one byte) is 104 only.

## Client requests

`clientd3d/protocol.c` in both:

| Request | `original` | `server104` |
|---|---|---|
| `BP_REQ_DROP` | object list: count (2), then per object id (4) + amount (4) for number objects; objects with amount ≤ 0 are skipped (`u:clientd3d/protocol.c:41,262`) | one object: id (4) + amount (4) for number objects |
| `BP_REQ_INVENTORY_MOVE` | two WORDs | two object ids (4 each) |
| `AP_LOGIN` | ends after the password | third string, the secret key |
| `BP_DELETE_NEWS` (mail/news module) | — | news id + index |

## Message ids

`include/proto.h`, *checked*. Upstream defines 179 ids and 104 defines 189. All others match.

| Message | `original` | `server104` | Payload (104) |
|---|---|---|---|
| `AP_CLIENT_PATCH_OLD` | — | 12 | patch strings (login mode) |
| `AP_CLIENT_PATCH` | — | 13 | six strings: patch host, path, cache path, cache file, club file, reason (`s:clientd3d/server.c:2034`) |
| `AP_GUEST` (38) | defined, unhandled | handled | status (1), low (4), high (4) (`s:clientd3d/server.c:2059`) |
| `BP_AD_SELECTED` | — | 24 | client → server, byte |
| `BP_DELETE_NEWS` | — | 84 | client → server |
| `BP_REQ_STAT_CHANGE` | — | 156 | stat-reset feature |
| `BP_CHANGED_STATS` | — | 157 | stat-reset feature |
| `BP_CHANGED_STATS_OK` | — | 158 | stat-reset feature |
| `BP_CHANGED_STATS_NOT_OK` | — | 159 | stat-reset feature |
| `BP_STOP_WAVE` | — | 173 | rsc (4), object (4) (`s:clientd3d/server.c:1354`) |
| `BP_RADIUS_SHOOT` | — | 229 | icon, translation, animation, source (4), speed (1), flags (2), range (1), number (1), lighting (`s:clientd3d/server.c:1483`) |
| `BP_SECTOR_CHANGE` | — | 239 | sector (2), depth (1), scroll (1) (`s:clientd3d/server.c:1629`) |
| `BP_REQ_GET_FROM_CONTAINER` | **239** | **240** | |

## Server text formatting

Messages carry a format resource id followed by parameters. The formatter's codes decide how many bytes each parameter takes:
- `original` (`u:clientd3d/srvrstr.c:31`): `%d`/`%i`/`%s` take an id (4), `%q` takes a length-prefixed string, and `%%` is a literal `%`.
- `server104` adds two codes:
  - `%r`: a nested resource id plus *its own* parameters, decoded recursively.
  - positional `%s$2`-style parameters, reordered before decoding (`CheckMessageOrder`, `s:clientd3d/srvrstr.c:392`).
  - It also prints `% `, `%.`, `%,`, `%!` and `%?` literally.

**No switch needed.** Upstream's Kod uses no `%r` or `$N`; the eight `%r` matches in upstream Kod are all comments. So 104's formatter reads `original` strings unchanged. Keep one formatter.

## File formats

**`.rsc` / `rsc0000.rsb`** (`util/rscload.c:9`):
- `original` is **RSC version 4**: magic `RSC\x01`, version, count, then (id, NUL-terminated string) per resource.
- `server104` is **version 5**, with a language id (4) before each string. One resource can appear once per language.
- A reader must check the version.
- Keep the redbook lookup the same: the redbook token is the string of the configured resource (`RedbookRsc`, default `system_success_rsc`). In version 5 that is the English (language 0) string (`LookupRscRedbook` in 104).

**`.roo` rooms:**
- `original` files are **versions 12 and 13** (upstream's `resource/rooms`: 122 × v12, 143 × v13). Steam's install matches (124 × v12, 142 × v13).
- Upstream's client accepts ≥ 10 and branches on < 13 (`u:clientd3d/bspload.c:25,51,464`).
- `server104` files are **version 15**, and its client requires ≥ 14, where 14 = floating-point coordinates (`s:blakserv/roofile.h:25`, `s:clientd3d/bspload.c:25`).
- Clients need a v12/13 reader for `original` and `shards`. Port it from `u:clientd3d/bspload.c`.

## Values that differ inside unchanged layouts

- **Schools** (`kod/include/blakston.khd`):
  - `server104` adds spell school `SS_CRAFTING = 7` (`s:…/blakston.khd:2607`).
  - Skill schools: `original` has `SKS_TELEPATHY = 12`, `SKS_THIEVERY = 13` (`u:…/blakston.khd:2046`). `server104` has `SKS_THIEVERY = 12` and no telepathy.
- **Stat groups:**
  - `BP_STAT_GROUPS` sends 4 groups in `original` (condition, stats, spells, skills; `u:…/user.kod:2725`).
  - `server104` sends 5, adding quests (`s:…/user.kod:3876`).
  - The layout is count-prefixed in both.
- **Effects and flags only in 104** (`s:include/proto.h`):
  - `EFFECT_FIREWORKS = 18`
  - texture flag `CTF_RESET = 0x20`
  - light flag `LIGHT_FLAG_HIGHLIGHT = 0x08`
  - `DRAWFX_DITHERGREY = 0x0B`
- **Sounds:** in `BP_PLAY_WAVE`, the 104 client ignores the server's max volume and uses its own setting. The bytes are the same.

## What is the same

- **Framing:** length, CRC16, length, epoch byte. The client → server CRC is XORed with the per-session LCG stream (`blakserv/game.c`). The server → client type byte is XORed with the sliding redbook token (`blakserv/commcli.c` `SecurePacketBufferList`).
- **Login handshake, beacon and seeds:** `trysync.c` and `resync.c` are identical, and `synched.c` differs only as listed above.
- **Resync is broken the same way in both:** `GameSyncInputChar` compares a signed `char` with the `unsigned char` beacon (`u:blakserv/game.c:314`). Clients should not send `BP_RESYNC` to either.
- **Unknown messages are ignored:** upstream's client logs and ignores message ids it doesn't know. `HandleMessage`'s result is unused (`u:clientd3d/com.c:491`), and the redbook token is applied before dispatch, so it stays in step. Adding a message is safe for original clients.
- **Everything else:** every other message handler, after cosmetic normalization. That covers movement, turning, look, use, say, inventory, trade, spells/skills lists, enchantments, lighting, sounds and music, sector and wall animation, background overlays, mail and news, guilds, admin and DM.

## Shards changes

| Shards protocol | Change | Since |
|---|---|---|
| 0 | Identical to `original`. A server that sends no `AP_SHARDS_INFO` is version 0. | 2026-10-10 |
| 1 | `AP_SHARDS_INFO = 60` (login mode, server → client), sent right after `AP_LOGINOK`: protocol version (4), server name (string, from `[Shards] ServerName`). Clients on the `shards` ruleset read it; `original` clients ignore it (`blakserv/synched.c` `SynchedSendShardsInfo`, [ADR 0002](adr/0002-protocol-version.md)). | 2026-10-11 |

The Shards server announces its protocol version at login with `AP_SHARDS_INFO`, which original clients ignore ([ADR 0002](adr/0002-protocol-version.md)). The current version is `SHARDS_PROTOCOL_VERSION` in `include/shards.h`.

**Rules for a Shards change** ([ADR 0003](adr/0003-two-rulesets.md)):
- **Prefer no protocol change.** Kod and existing messages carry most features. For example, new stats are ordinary `BP_STAT` lines, and item tiers can use the rarity grade already in every object descriptor.
- **Additive only:**
  - new message ids
  - new user-command ids in unused ranges
  - fields appended after existing ones
- **Never reuse, renumber or reinterpret an existing id, field or flag bit.** That is what made 104 incompatible.
- **Version every change:** bump `SHARDS_PROTOCOL_VERSION` and add a row here giving the layout and the clients' handling.
- **Upstream's Windows client must keep working:** it ignores additions it doesn't know.
