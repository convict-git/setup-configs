#!/usr/bin/env bash

set -euo pipefail

CACHE_DIR="${HOME}/.cache/fd-cache"
mkdir -p "$CACHE_DIR"

# === CONFIG ===
EXPIRY_SECONDS=300  # 5 minutes
REFRESH_CACHE_TIME=60  # 1 minute

# === UTILS ===
get_mtime() {
  stat -f %m "$1" 2>/dev/null || echo 0
}

is_cache_fresh() {
  local file="$1"
  local now
  now=$(date +%s)
  local modified
  modified=$(get_mtime "$file")
  [[ $((now - modified)) -lt $REFRESH_CACHE_TIME ]]
}

# === HASH CACHE KEY ===
CWD="$(pwd)"
KEY="$(echo "${CWD} $*" | sha256sum | awk '{print $1}')"
CACHE_FILE="${CACHE_DIR}/${KEY}.txt"

# === BACKGROUND REFRESH ===
refresh_cache() {
  nohup bash -c "fd $* > \"$CACHE_FILE\"" >/dev/null 2>&1 &
}

# === MAIN LOGIC ===
if [[ -f "$CACHE_FILE" ]]; then
  cat "$CACHE_FILE"

  if ! is_cache_fresh "$CACHE_FILE"; then
    refresh_cache "$@"
  fi
else
  fd "$@" | tee "$CACHE_FILE"
fi

# === EXPIRED CACHE PURGING LOGIC ===
purge_expired_cache_async() {
  nohup bash -c '
    CACHE_DIR="'"$CACHE_DIR"'"
    EXPIRY_SECONDS="'"$EXPIRY_SECONDS"'"
    now=$(date +%s)
    find "$CACHE_DIR" -type f | while read -r file; do
      mtime=$(stat -f %m "$file" 2>/dev/null)
      if [[ -z "$mtime" ]]; then
        continue
      fi
      age=$((now - mtime))
      if [[ $age -ge $EXPIRY_SECONDS ]]; then
        rm -f "$file"
      fi
    done
  ' >/dev/null 2>&1 &
}

purge_expired_cache_async
