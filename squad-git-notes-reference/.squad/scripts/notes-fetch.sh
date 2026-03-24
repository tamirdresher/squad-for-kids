#!/usr/bin/env bash
# .squad/scripts/notes-fetch.sh
# Explicit fetch of squad notes from origin.
# Use this to sync notes manually. Ralph-watch runs this automatically.
#
# Usage: bash .squad/scripts/notes-fetch.sh [--quiet]

set -e
QUIET=""
[ "$1" = "--quiet" ] && QUIET="1"

log() { [ -z "$QUIET" ] && echo "$1"; }

git rev-parse --show-toplevel > /dev/null 2>&1 || { echo "ERROR: Not in a git repo"; exit 1; }

log "Fetching refs/notes/squad/* from origin..."
git fetch origin 'refs/notes/*:refs/notes/*'
log "Done."
