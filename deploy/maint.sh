#!/bin/sh
# Send commands to blakserv's maintenance port from inside its container.
# Commands end with CR, not LF (blakserv/maintenance.c).
#
#   docker compose -f deploy/docker-compose.yml exec blakserv maint "show status" ["who" ...]
set -e
{
  sleep 0.3
  for cmd in "$@"; do
    printf '%s\r' "$cmd"
    sleep 0.7
  done
  sleep 1
} | nc -q 1 127.0.0.1 9999 | tr -d '\r'
