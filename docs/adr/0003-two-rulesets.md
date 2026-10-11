# ADR 0003: Two rulesets, `original` and `shards`, and 104 features ported additively

- Status: Accepted
- Date: 2026-10-11
- Changes: [ADR 0001](0001-server-direction.md) decisions 3 and 4

## Context

ADR 0001 gave the clients three rulesets: `original`, `server104` and `shards`. It also brought Server 104's features into Shards by merging 104 code for v1.0.

The [protocol audit](../protocol-dialect.md) then showed how far upstream and 104 have drifted apart:
- **Object descriptor and flags:** 104 split upstream's packed object flags into five new fields. The descriptor is used by about 20 messages.
- **User commands:** 104 reused user-command id 7.
- **Smaller layout changes:** login, character creation, drop and inventory requests.
- **File formats:** 104 moved to RSC v5 and ROO v15.

Supporting both frozen dialects means two codecs, two file readers each, two asset sets and a three-server test matrix, for a server (104) we don't run long-term.

The 104 features we actually want don't need 104's protocol:
- **Training points and unbound energy** are ordinary stat lines. Upstream's `BP_STAT` already carries them (name rsc, `STAT_VALUE`, `STAT_INTEGER`; `s:…/user.kod:9049`).
- **Weapon tiers** map onto upstream's existing item rarity grade, which is sent in every object descriptor.

104's incompatibility came from *changing* existing fields and ids, not from adding features.

## Decision

1. **Clients support two rulesets:** `original` (upstream, frozen) and `shards`. `shards` is `original` plus numbered, additive changes, selected by the version the server announces ([ADR 0002](0002-protocol-version.md)). There is no `server104` ruleset.
2. **Each client migrates once, from 104 to `original`.** The migration list is in [protocol-dialect.md](../protocol-dialect.md).
   - Before switching, tag a last 104-capable release of each client, for play on Server 104 until Shards is hosted.
   - After switching, delete the 104-only code paths instead of keeping a seam.
3. **104 features are ported the Shards way, with 104 as a design reference.** For each feature:
   1. Use Kod and the messages that already exist. Stats, items, rarity, spells and rooms usually need nothing new on the wire.
   2. If the protocol must grow, grow it **additively only**:
      - new message ids
      - new user-command ids in unused ranges
      - fields appended after existing ones, under a new Shards protocol version
   3. Never reuse, renumber or reinterpret an existing id, field or flag bit.
   4. Copying 104's Kod is fine where it fits. Its C built-ins, room format (ROO v15) and resource format (RSC v5) come in only if a feature truly needs them, with an ADR.
4. **Upstream's Windows client stays a working Shards client.** It ignores additions it doesn't know. Keeping it working is a test of rule 3.

## Consequences

- One protocol for the clients: the `original` codecs, plus Shards changes gated by version.
- One `.rsb` reader (RSC v4) and one `.roo` reader (ROO v12/13) per client, unless a later ADR adopts a newer format.
- One asset set per server, and a two-server test matrix (upstream reference and Shards) instead of three.
- **New client builds can't play on Server 104.** The tagged releases can.
- **The browser's hosted world moves from 104 to Shards when Shards is hosted.** That is a fresh world for anyone playing there.
- **104 extras that live in its protocol are redone our way if we want them:** name colours, minimap categories, the preferences window and the crafting school.
- **Art provenance changes:** the art comes from the original/Steam install instead of the 104 install. Serving it from `/assets` is permitted (confirmed 2026-10-11) on two conditions: the client and server stay open source, and the art is never committed to a repo.

## Alternatives

- **Three rulesets** (ADR 0001 as written): rejected. It has the most code and testing, and keeps a dialect for a server we're leaving.
- **`server104` and `shards`, with Shards adopting 104's protocol:** rejected.
  - Shards would inherit 104's breaking changes and file formats.
  - Upstream's client could no longer play on Shards.
  - Upstream fixes would get harder to merge.
- **Merge 104's C and Kod wholesale for v1.0:** rejected. It drags in protocol changes, ROO v15 and RSC v5, and Kod written for 104's built-ins. Ported feature by feature, each change stays small and additive.
