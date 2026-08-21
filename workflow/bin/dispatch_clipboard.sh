#!/bin/bash
# Keyword entry point. Reads the current clipboard text and forwards it to
# dispatch.sh, which handles device discovery and routing.
#
# The type is pinned to "clipboard" so the payload always lands in the
# device's clipboard. Letting dispatch.sh classify it would route a copied
# link through the share plugin, which opens it in the phone's browser.

set -euo pipefail
IFS=$'\n\t'

payload=$(pbpaste)
if [[ -z $payload ]]; then
  printf 'Clipboard is empty\n'
  exit 0
fi

exec "$(dirname "$0")/dispatch.sh" "$payload" clipboard
