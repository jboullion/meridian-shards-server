/*
 * shards.h:  Meridian: Shards additions shared by the server (and any client that wants them).
 *
 * SHARDS_PROTOCOL_VERSION is the Shards protocol version the server announces in
 * AP_SHARDS_INFO right after AP_LOGINOK (docs/adr/0002-protocol-version.md).
 * Bump it with every protocol-visible change and add a row to the "Shards changes"
 * table in docs/protocol-dialect.md. Never reuse or renumber a version.
 *
 *   0  identical to upstream ("original"); a server that sends no AP_SHARDS_INFO
 *   1  AP_SHARDS_INFO itself
 */

#ifndef _SHARDS_H
#define _SHARDS_H

#define SHARDS_PROTOCOL_VERSION 1

#endif /* #ifndef _SHARDS_H */
