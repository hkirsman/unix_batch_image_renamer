#!/usr/bin/env bash
#
# Run fixture-based rename tests against the Docker image.
# Copies media only into .test-work/, runs the renamer, asserts the result name.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASES_DIR="$ROOT/tests/cases"
WORK_ROOT="$ROOT/.test-work"
IMAGE="${IMAGE:-hkirsman/unix-batch-image-renamer}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is required to run tests." >&2
  exit 1
fi

if [ ! -d "$CASES_DIR" ]; then
  echo "Error: cases directory not found: $CASES_DIR" >&2
  exit 1
fi

shopt -s nullglob
cases=("$CASES_DIR"/*/)
if [ ${#cases[@]} -eq 0 ]; then
  echo "Error: no test cases under $CASES_DIR" >&2
  exit 1
fi

failed=0
passed=0

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

for case_dir in "${cases[@]}"; do
  case_name="$(basename -- "$case_dir")"
  expected_file="$case_dir/expected.txt"
  work_dir="$WORK_ROOT/$case_name"

  echo "==> Case: $case_name"

  if [ ! -f "$expected_file" ]; then
    echo "FAIL: $case_name — missing expected.txt" >&2
    failed=$((failed + 1))
    continue
  fi

  expected="$(tr -d '\r\n' < "$expected_file")"
  if [ -z "$expected" ] || [[ "$expected" == PLACEHOLDER* ]]; then
    echo "FAIL: $case_name — expected.txt is empty or still a placeholder" >&2
    failed=$((failed + 1))
    continue
  fi

  rm -rf "$work_dir"
  mkdir -p "$work_dir"

  media_count=0
  original_name=""
  for src in "$case_dir"*; do
    [ -f "$src" ] || continue
    if is_media "$src"; then
      cp -- "$src" "$work_dir/"
      original_name="$(basename -- "$src")"
      media_count=$((media_count + 1))
    fi
  done

  if [ "$media_count" -eq 0 ]; then
    echo "FAIL: $case_name — no media files in case directory" >&2
    failed=$((failed + 1))
    rm -rf "$work_dir"
    continue
  fi
  if [ "$media_count" -gt 1 ]; then
    echo "FAIL: $case_name — expected 1 media file in case, found $media_count" >&2
    failed=$((failed + 1))
    rm -rf "$work_dir"
    continue
  fi

  # Resolve a Docker-friendly host path. On Git Bash / MSYS, default path
  # conversion rewrites "/app" to "C:/Program Files/Git/app", so disable it.
  mount_dir="$work_dir"
  if command -v cygpath >/dev/null 2>&1; then
    mount_dir="$(cygpath -w "$work_dir")"
  elif win_pwd="$(cd "$ROOT" && pwd -W 2>/dev/null)"; then
    mount_dir="${win_pwd}/.test-work/${case_name}"
  fi
  mount_dir="${mount_dir//\\//}"

  if ! MSYS_NO_PATHCONV=1 docker run --rm -t --volume "${mount_dir}:/app:cached" "$IMAGE"; then
    echo "FAIL: $case_name — docker run failed (image: $IMAGE, mount: $mount_dir)" >&2
    failed=$((failed + 1))
    rm -rf "$work_dir"
    continue
  fi

  actual_files=()
  for f in "$work_dir"/*; do
    [ -f "$f" ] || continue
    if is_media "$f"; then
      actual_files+=("$(basename -- "$f")")
    fi
  done

  if [ ${#actual_files[@]} -eq 0 ]; then
    echo "FAIL: $original_name — no media files left after rename" >&2
    echo "  expected: $expected" >&2
    failed=$((failed + 1))
  elif [ ${#actual_files[@]} -gt 1 ]; then
    echo "FAIL: $original_name — expected 1 media file, found ${#actual_files[@]}: ${actual_files[*]}" >&2
    echo "  expected: $expected" >&2
    failed=$((failed + 1))
  elif [ "${actual_files[0]}" != "$expected" ]; then
    echo "FAIL: $original_name → ${actual_files[0]}" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   ${actual_files[0]}" >&2
    failed=$((failed + 1))
  else
    echo "PASS: $original_name → ${actual_files[0]}"
    passed=$((passed + 1))
  fi

  rm -rf "$work_dir"
done

rmdir "$WORK_ROOT" 2>/dev/null || true

echo ""
echo "Tests: $passed passed, $failed failed"
if [ "$failed" -ne 0 ]; then
  exit 1
fi
