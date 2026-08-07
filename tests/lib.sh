#!/usr/bin/env bash
# Shared helpers for test runners.
# shellcheck shell=bash

is_media() {
  local base ext
  base="$(basename -- "$1")"
  ext="${base##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    jpg|jpeg|heic|mov) return 0 ;;
    *) return 1 ;;
  esac
}

# Resolve a Docker-friendly host path. On Git Bash / MSYS, default path
# conversion rewrites "/app" to "C:/Program Files/Git/app", so callers must
# also set MSYS_NO_PATHCONV=1 for docker run.
docker_mount_dir() {
  local work_dir="$1"
  local mount_dir
  if command -v cygpath >/dev/null 2>&1; then
    mount_dir="$(cygpath -w "$work_dir")"
  elif mount_dir="$(cd "$work_dir" && pwd -W 2>/dev/null)"; then
    :
  else
    mount_dir="$work_dir"
  fi
  mount_dir="${mount_dir//\\//}"
  printf '%s' "$mount_dir"
}

list_media_basenames_sorted() {
  local dir="$1"
  local f
  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    if is_media "$f"; then
      basename -- "$f"
    fi
  done | LC_ALL=C sort
}
