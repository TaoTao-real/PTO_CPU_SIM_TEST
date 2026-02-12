#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

MODE="${1:-ca}" # ca|pv
TESTDIR="${2:-}"

export MODE

echo "[1/4] Check environment"
"$ROOT_DIR/scripts/check_env.sh"

echo "[2/4] CPU simulation"
(cd "$ROOT_DIR" && bash run.sh)

echo "[3/4] Simulator ($MODE)"
(cd "$ROOT_DIR" && bash run_sim_310b.sh "$MODE")

echo "[4/4] Batch testcases (optional)"
if [[ -n "$TESTDIR" ]]; then
  (cd "$ROOT_DIR" && bash run_testcases_sim.sh "$MODE" "$TESTDIR")
else
  echo "skip (no testcase dir provided)"
fi

