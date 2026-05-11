# Shared helpers for the KDE Connect Alfred workflow.
# Sourced by dispatch.sh, choose_device.sh, send.sh.

set -euo pipefail

KDECONNECT_CLI="${KDECONNECT_CLI:-/Applications/KDE Connect.app/Contents/MacOS/kdeconnect-cli}"
BUNDLE_ID="${alfred_workflow_bundleid:-com.leonvogt.kde-connect}"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

# Escape a string for embedding inside JSON double quotes.
# Reads from $1 (or stdin if no arg). Writes the escaped form to stdout.
json_escape() {
  local s
  if (( $# > 0 )); then s=$1; else s=$(cat); fi
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  if [[ $s == *[$'\x00'-$'\x1f']* ]]; then
    s=$(LC_ALL=C printf '%s' "$s" | perl -pe 's/([\x00-\x1f])/sprintf("\\u%04x", ord($1))/ge')
  fi
  printf '%s' "$s"
}

# Classify a payload into text / url / file.
# Multiple files arrive tab-separated from Alfred's Universal Action.
classify_payload() {
  local s=$1
  [[ -z $s ]] && { printf 'text'; return; }
  if [[ $s =~ ^(https?|ftp|file):// ]]; then printf 'url'; return; fi
  local IFS=$'\t' token all_paths=1
  for token in $s; do
    [[ -e $token ]] || { all_paths=0; break; }
  done
  if (( all_paths )); then printf 'file'; else printf 'text'; fi
}

# List paired & reachable devices, one per line: "<id>\t<name>".
# Output is empty when no devices are reachable.
#
# Sending to a paired-but-not-reachable device fails with "No such object
# path .../share" because the share plugin is only registered while the
# device is actively connected. So we filter to paired+reachable here.
#
# The macOS KDE Connect daemon is started on demand by the first CLI call,
# which often returns "0 devices found" while it warms up. We retry briefly
# until it responds with a device list (or the budget runs out).
kdec_list_devices() {
  [[ -x "$KDECONNECT_CLI" ]] || die "kdeconnect-cli not found at: $KDECONNECT_CLI"
  local raw out i
  for (( i=0; i<6; i++ )); do
    raw=$("$KDECONNECT_CLI" --list-available --id-name-only 2>/dev/null || true)
    # Device IDs are 32 hex chars on Android/desktop; iOS uses an
    # underscore-separated UUID (e.g. 583305bd_64fe_43ef_af5a_e508c7581736).
    # Match any leading hex/underscore token, then split on the first space.
    out=$(printf '%s\n' "$raw" \
      | awk 'match($0, /^[0-9a-f_]+ /) {
          id = substr($0, 1, RLENGTH - 1)
          name = substr($0, RLENGTH + 1)
          printf "%s\t%s\n", id, name
        }')
    [[ -n $out ]] && { printf '%s\n' "$out"; return; }
    sleep 0.25
  done
}

# List paired-but-not-reachable device names, one per line.
# Used to give the user a more helpful error when nothing is reachable.
kdec_list_paired_unreachable() {
  [[ -x "$KDECONNECT_CLI" ]] || return 0
  # Full --list-devices output annotates each device with (paired) or
  # (reachable). We want devices marked (paired) only — they're trusted
  # but the Mac daemon doesn't currently see them on the network.
  "$KDECONNECT_CLI" --list-devices 2>/dev/null \
    | awk -F': ' '/\(paired\)$/ {
        sub(/^- /, "", $1)
        print $1
      }'
}

# KDE Connect's macOS CLI silently drops files whose names contain U+202F
# (narrow no-break space) — common in macOS-localized screenshot filenames
# like "screenshot 2026-05-11 at 10 .36.48.png". The CLI prints
# "Shared file:///…" but nothing reaches the device. Workaround: stage a copy
# in $TMPDIR with U+202F replaced by ASCII space and share that. The temp
# file is left for macOS to clean up so we never delete it mid-transfer.
_kdec_normalize_path() {
  local path=$1
  [[ $path != *$'\xe2\x80\xaf'* ]] && { printf '%s' "$path"; return; }
  local safe_name tmp_dir
  safe_name=${path##*/}
  safe_name=${safe_name//$'\xe2\x80\xaf'/ }
  tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/kdec.XXXXXX")
  cp "$path" "$tmp_dir/$safe_name"
  printf '%s' "$tmp_dir/$safe_name"
}

# Send a payload to a single device.
#   $1 device_id
#   $2 payload (text, url, or tab-separated file list)
#   $3 payload_type (text|url|file)
# On failure, prints a cleaned-up reason to stdout and returns 1.
kdec_send() {
  local device_id=$1 payload=$2 payload_type=$3
  [[ -n $device_id ]] || { printf 'missing device id'; return 1; }
  [[ -x "$KDECONNECT_CLI" ]] || { printf 'kdeconnect-cli not found at: %s' "$KDECONNECT_CLI"; return 1; }

  local -a errors=()
  local stderr rc=0

  _kdec_one() {
    local flag=$1 arg=$2
    stderr=$("$KDECONNECT_CLI" "$flag" "$arg" -d "$device_id" 2>&1 >/dev/null) || {
      errors+=("$stderr")
      return 1
    }
  }

  case "$payload_type" in
    text) _kdec_one --share-text "$payload" || rc=1 ;;
    url)  _kdec_one --share      "$payload" || rc=1 ;;
    file)
      local path send_path tmp_dir
      while IFS= read -r path; do
        [[ -z $path ]] && continue
        send_path=$(_kdec_normalize_path "$path")
        _kdec_one --share "$send_path" || rc=1
      done < <(printf '%s' "$payload" | tr '\t' '\n')
      ;;
    *) printf 'unknown payload type: %s' "$payload_type"; return 1 ;;
  esac

  if (( rc != 0 )); then
    # The first stderr line is usually noisy DBus activation chatter;
    # the real cause is on the last non-noisy line.
    local reason
    reason=$(printf '%s\n' "${errors[0]}" \
      | grep -v 'error activating kdeconnectd' \
      | tail -n 1)
    [[ -z $reason ]] && reason="unknown error"
    printf '%s' "$reason"
    return 1
  fi
}
