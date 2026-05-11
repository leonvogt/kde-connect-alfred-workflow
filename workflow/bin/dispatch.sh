#!/bin/bash
# Entry point after the Universal Action.
#
# Receives the payload as $1 (text, URL, or tab-separated file paths).
# Routes by reachable-device count:
#   0 devices  → print error message (Notification node shows it)
#   1 device   → send immediately
#   2+ devices → hand off to the chooser via the "choose" external trigger

set -euo pipefail
IFS=$'\n\t'

source "$(dirname "$0")/_lib.sh"

payload=${1-}
payload_type=$(classify_payload "$payload")

devices=$(kdec_list_devices || true)
if [[ -z $devices ]]; then
  unreachable=$(kdec_list_paired_unreachable || true)
  if [[ -n $unreachable ]]; then
    names=$(printf '%s' "$unreachable" | paste -sd ',' - | sed 's/,/, /g')
    printf 'No KDE Connect device reachable (paired but offline: %s)\n' "$names"
  else
    printf 'No KDE Connect device reachable\n'
  fi
  exit 0
fi

count=$(printf '%s\n' "$devices" | wc -l | tr -d ' ')

if (( count == 1 )); then
  device_id=${devices%%$'\t'*}
  device_name=${devices#*$'\t'}
  if reason=$(kdec_send "$device_id" "$payload" "$payload_type"); then
    printf 'Sent to %s\n' "$device_name"
  else
    printf 'Failed to send to %s: %s\n' "$device_name" "$reason"
    exit 1
  fi
  exit 0
fi

# 2+ devices: open the chooser. AppleScript strings are wrapped in double
# quotes; backslashes and quotes inside the argument must be escaped.
escaped=${payload//\\/\\\\}
escaped=${escaped//\"/\\\"}
/usr/bin/osascript <<EOF >/dev/null
tell application id "com.runningwithcrayons.Alfred" to run trigger "choose" in workflow "$BUNDLE_ID" with argument "$escaped"
EOF
