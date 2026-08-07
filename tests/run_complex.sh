#!/usr/bin/env bash
#
# Multi-file / potential-duplicate fixtures under tests/cases_complex/.
# Each case is run twice: MOVE_DUPLICATES=yes and MOVE_DUPLICATES=no.
#
# Expected files (committed next to fixtures):
#   expected_yes_duplicates.txt  — sorted basenames under duplicates/ after yes
#   expected_no_toplevel.txt     — sorted basenames left top-level after no
#   expected_potential_duplicates.txt — exact potential_duplicates.txt (LF)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/tests/lib.sh"

CASES_DIR="$ROOT/tests/cases_complex"
WORK_ROOT="$ROOT/.test-work/complex"
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

normalize_lf() {
  tr -d '\r'
}

assert_file_list() {
  local label="$1"
  local dir="$2"
  local expected_file="$3"
  local actual expected

  actual="$(list_media_basenames_sorted "$dir")"
  expected="$(normalize_lf < "$expected_file" | sed '/^$/d' | LC_ALL=C sort)"

  if [ "$actual" = "$expected" ]; then
    return 0
  fi

  echo "FAIL: $label" >&2
  echo "  expected ($expected_file):" >&2
  echo "$expected" | sed 's/^/    /' >&2
  echo "  actual:" >&2
  if [ -z "$actual" ]; then
    echo "    (none)" >&2
  else
    echo "$actual" | sed 's/^/    /' >&2
  fi
  return 1
}

run_case_variant() {
  local case_dir="$1"
  local case_name="$2"
  local move_flag="$3"
  local work_dir="$4"

  rm -rf "$work_dir"
  mkdir -p "$work_dir"

  local src media_count=0
  for src in "$case_dir"*; do
    [ -f "$src" ] || continue
    if is_media "$src"; then
      cp -- "$src" "$work_dir/"
      media_count=$((media_count + 1))
    fi
  done

  if [ "$media_count" -lt 2 ]; then
    echo "FAIL: $case_name ($move_flag) — need ≥2 media files, found $media_count" >&2
    return 1
  fi

  local mount_dir
  mount_dir="$(docker_mount_dir "$work_dir")"

  if ! MSYS_NO_PATHCONV=1 docker run --rm -t \
      -e "MOVE_DUPLICATES=$move_flag" \
      --volume "${mount_dir}:/app:cached" \
      "$IMAGE"; then
    echo "FAIL: $case_name ($move_flag) — docker run failed" >&2
    return 1
  fi

  local ok=0

  if ! diff -u \
      <(normalize_lf < "$case_dir/expected_potential_duplicates.txt") \
      <(normalize_lf < "$work_dir/potential_duplicates.txt") >/dev/null; then
    echo "FAIL: $case_name ($move_flag) — potential_duplicates.txt mismatch" >&2
    diff -u \
      <(normalize_lf < "$case_dir/expected_potential_duplicates.txt") \
      <(normalize_lf < "$work_dir/potential_duplicates.txt") >&2 || true
    ok=1
  fi

  if [ "$move_flag" = "yes" ]; then
    if [ ! -d "$work_dir/duplicates" ]; then
      echo "FAIL: $case_name (yes) — duplicates/ directory missing" >&2
      ok=1
    elif ! assert_file_list "$case_name (yes) duplicates/" "$work_dir/duplicates" \
        "$case_dir/expected_yes_duplicates.txt"; then
      ok=1
    fi
    # Top-level should have no media left.
    local leftover
    leftover="$(list_media_basenames_sorted "$work_dir")"
    if [ -n "$leftover" ]; then
      echo "FAIL: $case_name (yes) — media still at top level:" >&2
      echo "$leftover" | sed 's/^/    /' >&2
      ok=1
    fi
  else
    if [ -d "$work_dir/duplicates" ] && [ -n "$(list_media_basenames_sorted "$work_dir/duplicates")" ]; then
      echo "FAIL: $case_name (no) — duplicates/ should be empty/absent" >&2
      ok=1
    fi
    if ! assert_file_list "$case_name (no) top-level" "$work_dir" \
        "$case_dir/expected_no_toplevel.txt"; then
      ok=1
    fi
  fi

  if [ "$ok" -eq 0 ]; then
    echo "PASS: $case_name (MOVE_DUPLICATES=$move_flag)"
    return 0
  fi
  return 1
}

echo "=== Complex fixtures (cases_complex) ==="

for case_dir in "${cases[@]}"; do
  case_name="$(basename -- "$case_dir")"
  echo "==> Case: $case_name"

  local_missing=0
  for req in expected_yes_duplicates.txt expected_no_toplevel.txt expected_potential_duplicates.txt; do
    if [ ! -f "$case_dir/$req" ]; then
      echo "FAIL: $case_name — missing $req" >&2
      local_missing=1
    fi
  done
  if [ "$local_missing" -ne 0 ]; then
    failed=$((failed + 1))
    continue
  fi

  for move_flag in yes no; do
    work_dir="$WORK_ROOT/${case_name}-${move_flag}"
    if run_case_variant "$case_dir" "$case_name" "$move_flag" "$work_dir"; then
      passed=$((passed + 1))
    else
      failed=$((failed + 1))
    fi
    if [ "${KEEP_WORK:-0}" != "1" ]; then
      rm -rf "$work_dir"
    else
      echo "Keeping work dir: $work_dir"
    fi
  done
done

rmdir "$WORK_ROOT" 2>/dev/null || true
rmdir "$ROOT/.test-work" 2>/dev/null || true

echo ""
echo "Complex tests: $passed passed, $failed failed"
if [ "$failed" -ne 0 ]; then
  exit 1
fi
