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
  # Nothing reachable on the first try — ask the daemon to re-scan the network,
  # mirroring the app's Refresh button. Paired-but-offline devices often
  # reconnect after this, but it can take several seconds, so poll with a larger
  # budget (~5s) instead of the fast default — otherwise we'd give up before the
  # device finishes reconnecting and wrongly report "no device reachable".
  "$KDECONNECT_CLI" --refresh >/dev/null 2>&1 || true
  devices=$(kdec_list_devices 10 0.5 || true)
fi
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
  kdec_send_and_report "$device_id" "$payload" "$payload_type" "$device_name" || exit 1
  exit 0
fi

# 2+ devices: open the chooser. AppleScript strings are wrapped in double
# quotes; backslashes and quotes inside the argument must be escaped.
escaped=${payload//\\/\\\\}
escaped=${escaped//\"/\\\"}
/usr/bin/osascript <<EOF >/dev/null
tell application id "com.runningwithcrayons.Alfred" to run trigger "choose" in workflow "$BUNDLE_ID" with argument "$escaped"
EOF
