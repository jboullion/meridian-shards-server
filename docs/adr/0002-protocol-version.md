# ADR 0002: Announce the Shards protocol version at login

- Status: Accepted (implemented 2026-10-11)
- Date: 2026-10-11
- Builds on: [ADR 0001](0001-server-direction.md), [ADR 0003](0003-two-rulesets.md), [protocol-dialect.md](../protocol-dialect.md)

## Context

The clients pick a ruleset per server: `original` or `shards` ([ADR 0003](0003-two-rulesets.md)). `original` is frozen, so a client can hardcode it. `shards` is `original` plus additive changes over time, and one client build should work with every Shards server version it meets. That includes a local dev server that is newer or older than the hosted one.

So the client needs to learn, before any world packet arrives, which Shards protocol version the server speaks. That's the version listed in [protocol-dialect.md](../protocol-dialect.md#shards-changes).

What the code allows:
- **Unknown ids are safe for upstream's client.** It ignores message ids it doesn't know: `HandleMessage`'s result is unused (`clientd3d/com.c:491`), and the redbook token is applied before dispatch (`clientd3d/server.c` `HandleMessage`), so the token stays in step. Upstream's Windows client can keep playing on Shards.
- **Changing an existing message is not safe.** `AP_LOGINOK` must stay exactly one byte: upstream's client rejects any other length (`HandleLoginOk`, `len != SIZE_ADMIN`).
- **Free ids:** login-mode (`AP_*`) ids 40 and up are unused in both upstream and 104 (`include/proto.h`).

## Decision

1. **Add `AP_SHARDS_INFO = 60`,** a login-mode message from server to client. Sent immediately after `AP_LOGINOK` (`blakserv/synched.c` `SynchedAcceptLogin`):

   | Field | Size | Meaning |
   |---|---|---|
   | type | 1 | `AP_SHARDS_INFO` (60) |
   | protocol version | 4 | the Shards protocol version from `protocol-dialect.md` |
   | server name | string | length-prefixed, e.g. "Meridian: Shards" |

2. **The version lives in one place:** a `#define SHARDS_PROTOCOL_VERSION` in a new header (`include/shards.h`), bumped with each entry in `protocol-dialect.md`'s change table.
3. **Clients on the `shards` ruleset** start from the `original` codecs and enable each Shards change whose version is ≤ the announced one. With no `AP_SHARDS_INFO` (an older Shards build), they assume version 0, which is `original`.
4. **The `original` ruleset** ignores `AP_SHARDS_INFO`.

## Consequences

- One small, additive server change: a new header, a few lines in `synched.c` and an id in `include/proto.h`.
- Clients that don't know `AP_SHARDS_INFO` are unaffected: upstream's Windows client and the clients' `original` ruleset.
- Later Shards changes must stay ordered by version. A change can't be removed or renumbered once a release has shipped it.
- If Kod ever needs the version (for example, to send old layouts to old clients), add a built-in or a Kod constant. That's not needed now.

## Implementation

Implemented 2026-10-11:
- `include/shards.h`: `SHARDS_PROTOCOL_VERSION`, now 1. Version 1 is the message itself.
- `include/proto.h`: `AP_SHARDS_INFO = 60`.
- `blakserv/synched.c`: `SynchedSendShardsInfo`, called from `VerifyLogin` right after `AP_LOGINOK`.
- The server name comes from the new `[Shards] ServerName` setting (`blakserv/config.c`, default "Meridian: Shards"). `config/blakserv.cfg` sets "Meridian: Shards (local)".

Verified:
- **Linux build, `tools/login-check.py`:** `AP_LOGINOK`, then `AP_SHARDS_INFO` (protocol 1, "Meridian: Shards"), then `AP_GETCHOICE`.
- **Upstream's Windows client (7.37) on the same server:** its debug log shows "Got unknown message type 60 from server". It then went on to character selection as normal.

## Alternatives

- **Extend `AP_LOGINOK`:** rejected. It breaks upstream's client (exact length check).
- **Send it in game mode** (after `BP_PLAYER`): rejected. Character selection (`BP_CHARACTERS`, `BP_CHARINFO`) happens before that and may change in Shards.
- **Version in `servers.json` only:** rejected as the only source. A config file drifts from the server it describes. Keep it as a hint for the login screen if useful.
- **The client version in `AP_LOGIN`, with the server adapting to the client:** rejected for now. It means the server keeps old layouts alive. Revisit only if old clients must keep working through a breaking change.
