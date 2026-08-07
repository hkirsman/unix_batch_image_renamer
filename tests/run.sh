#!/usr/bin/env bash
#
# Run all fixture suites (rename + complex). Image must already be built,
# or use `make test` which builds first.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/tests/run_rename.sh"
bash "$ROOT/tests/run_complex.sh"

echo ""
echo "All fixture suites passed."
