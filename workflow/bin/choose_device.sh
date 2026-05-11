#!/bin/bash
# Script Filter: device chooser for the 2+ device case.
#
# Reads the payload from the `payload` workflow variable, which an
# "Argument and Variables" utility sets from the "choose" external
# trigger's argument before Alfred renders this Script Filter — that way
# the payload is available here without pre-filling the chooser's search
# field. Emits one item per reachable device; each item carries the
# variables needed by send.sh down the pipeline.

set -euo pipefail
IFS=$'\n\t'

source "$(dirname "$0")/_lib.sh"

payload=${payload:-}
payload_type=$(classify_payload "$payload")

emit_item() {
  local id=$1 name=$2
  printf '    {"uid":"%s","title":"%s","subtitle":"Send via KDE Connect","arg":"%s","icon":{"path":"icon.png"},"variables":{"device_id":"%s","device_name":"%s","payload":"%s","payload_type":"%s"}}' \
    "$(json_escape "$id")" \
    "$(json_escape "$name")" \
    "$(json_escape "$id")" \
    "$(json_escape "$id")" \
    "$(json_escape "$name")" \
    "$(json_escape "$payload")" \
    "$payload_type"
}

devices=$(kdec_list_devices || true)

printf '{"items":[\n'
if [[ -z $devices ]]; then
  unreachable=$(kdec_list_paired_unreachable || true)
  if [[ -n $unreachable ]]; then
    names=$(printf '%s' "$unreachable" | paste -sd ',' - | sed 's/,/, /g')
    subtitle="Paired but offline: $names"
  else
    subtitle="Make sure the device is paired and on the same network"
  fi
  printf '    {"title":"No KDE Connect device reachable","subtitle":"%s","valid":false,"icon":{"path":"icon.png"}}\n' \
    "$(json_escape "$subtitle")"
else
  first=1
  while IFS=$'\t' read -r id name; do
    [[ -z $id ]] && continue
    (( first )) || printf ',\n'
    emit_item "$id" "$name"
    first=0
  done <<< "$devices"
  printf '\n'
fi
printf ']}\n'
