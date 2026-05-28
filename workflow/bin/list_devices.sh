#!/bin/bash
# Script Filter: list all known KDE Connect devices with their connection
# status. Triggers a network refresh first so paired-but-offline devices
# have a chance to come back online (mirrors the app's Refresh button).
#
# `--list-devices` annotates each line as one of:
#   - Name: id (paired)
#   - Name: id (reachable)
#   - Name: id (paired and reachable)
# We map those to ● Connected / Paired, offline / Discovered (not paired)
# and sort connected devices to the top so the most actionable rows appear
# first. The bullet character gives the online row visual weight; subtitles
# are otherwise just plain text since Alfred doesn't expose per-row colors.
# The list is informational only (Enter does nothing) — the macOS build of
# kdeconnect-cli doesn't expose a ping endpoint, and other CLI actions
# would have user-visible side effects on the phone.

set -euo pipefail
IFS=$'\n\t'

source "$(dirname "$0")/_lib.sh"

[[ -x "$KDECONNECT_CLI" ]] || die "kdeconnect-cli not found at: $KDECONNECT_CLI"

# Ask the daemon to rescan the network. Harmless if it's already up to date.
"$KDECONNECT_CLI" --refresh >/dev/null 2>&1 || true

# Give the daemon a brief moment to update its device list after the refresh.
# Without this, --list-devices often reflects pre-refresh state on the first
# call following a cold-start of kdeconnectd.
raw=""
for (( i=0; i<6; i++ )); do
  raw=$("$KDECONNECT_CLI" --list-devices 2>/dev/null || true)
  [[ -n $raw ]] && break
  sleep 0.25
done

emit_item() {
  local id=$1 name=$2 status=$3 valid=$4
  printf '%s    {"uid":"%s","title":"%s","subtitle":"%s","arg":"%s","valid":%s,"icon":{"path":"icon.png"},"variables":{"device_id":"%s","device_name":"%s"}}' \
    "$separator" \
    "$(json_escape "$id")" \
    "$(json_escape "$name")" \
    "$(json_escape "$status")" \
    "$(json_escape "$id")" \
    "$valid" \
    "$(json_escape "$id")" \
    "$(json_escape "$name")"
}

separator=""
printf '{"items":[\n'

# Sort lines by status priority so connected devices are listed first.
# Stable sort preserves the daemon's original order within each group.
raw_sorted=$(awk '
  /\(paired and reachable\)$/ { print "0\t" $0; next }
  /\(reachable\)$/            { print "1\t" $0; next }
  /\(paired\)$/                { print "2\t" $0; next }
                              { print "3\t" $0 }
' <<< "$raw" | LC_ALL=C sort -t$'\t' -k1,1n -s | cut -f2-)

while IFS= read -r line; do
  # Lines look like: "- Pixel 10 Pro: a29f1a03... (paired and reachable)"
  [[ $line == "- "* ]] || continue
  rest=${line#- }
  name=${rest%%: *}
  rest=${rest#*: }
  id=${rest%% *}
  flags=${rest#"$id "}
  case "$flags" in
    "(paired and reachable)") status="● Connected" ;;
    "(paired)")               status="Paired, offline" ;;
    "(reachable)")            status="Discovered (not paired)" ;;
    *)                        status="Unknown state" ;;
  esac
  emit_item "$id" "$name" "$status" "false"
  separator=$',\n'
done <<< "$raw_sorted"

if [[ -z $separator ]]; then
  printf '    {"title":"No KDE Connect devices found","subtitle":"Refresh ran; nothing visible on the network","valid":false,"icon":{"path":"icon.png"}}'
fi

printf '\n]}\n'
