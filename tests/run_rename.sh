#!/usr/bin/env bash
#
# Single-file rename fixtures under tests/cases_rename/.
# Copies media only into .test-work/, runs the renamer, asserts the result name.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/tests/lib.sh"

CASES_DIR="$ROOT/tests/cases_rename"
WORK_ROOT="$ROOT/.test-work/rename"
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

echo "=== Rename fixtures (cases_rename) ==="

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

  mount_dir="$(docker_mount_dir "$work_dir")"

  if ! MSYS_NO_PATHCONV=1 docker run --rm -t --volume "${mount_dir}:/app:cached" "$IMAGE"; then
    echo "FAIL: $case_name — docker run failed (image: $IMAGE, mount: $mount_dir)" >&2
    failed=$((failed + 1))
    rm -rf "$work_dir"
    continue
  fi

  actual_files=()
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    actual_files+=("$line")
  done < <(list_media_basenames_sorted "$work_dir")

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

  if [ "${KEEP_WORK:-0}" != "1" ]; then
    rm -rf "$work_dir"
  else
    echo "Keeping work dir: $work_dir"
  fi
done

rmdir "$WORK_ROOT" 2>/dev/null || true

echo ""
echo "Rename tests: $passed passed, $failed failed"
if [ "$failed" -ne 0 ]; then
  exit 1
fi
