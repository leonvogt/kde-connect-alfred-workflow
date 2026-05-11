#!/bin/bash
# Final step after the chooser. Sends the payload to the selected device.
#
# Inputs come from workflow variables Alfred exports to the environment:
#   payload, payload_type, device_id, device_name
#
# Prints a single line — the human-readable result — for the downstream
# Notification node ({query}).

set -euo pipefail
IFS=$'\n\t'

source "$(dirname "$0")/_lib.sh"

payload=${payload-}
payload_type=${payload_type-text}
device_id=${device_id-}
device_name=${device_name-$device_id}

if reason=$(kdec_send "$device_id" "$payload" "$payload_type"); then
  printf 'Sent to %s\n' "$device_name"
else
  printf 'Failed to send to %s: %s\n' "$device_name" "$reason"
  exit 1
fi
