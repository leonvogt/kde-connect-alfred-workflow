#!/bin/bash
# Keyword entry point. Reads the current clipboard text and forwards it to
# dispatch.sh, which handles device discovery and routing.

set -euo pipefail
IFS=$'\n\t'

payload=$(pbpaste)
if [[ -z $payload ]]; then
  printf 'Clipboard is empty\n'
  exit 0
fi

exec "$(dirname "$0")/dispatch.sh" "$payload"
