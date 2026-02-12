#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash docker/run_docker.sh --cann /abs/path/to/cann [--mode ca|pv] [--soc Ascend310B1] [--device 0] [--testcases testcases]

Notes:
  - This builds a local Docker image that contains only the open-source toolchain.
  - CANN is mounted at runtime (not copied into the image).
EOF
}

MODE="ca"
SOC="Ascend310B1"
DEVICE_ID="0"
TESTCASES=""
CANN_HOST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cann)
      CANN_HOST="${2:-}"; shift 2 ;;
    --mode)
      MODE="${2:-}"; shift 2 ;;
    --soc)
      SOC="${2:-}"; shift 2 ;;
    --device)
      DEVICE_ID="${2:-}"; shift 2 ;;
    --testcases)
      TESTCASES="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

[[ -n "$CANN_HOST" ]] || { echo "--cann is required" >&2; usage; exit 2; }
[[ -d "$CANN_HOST" ]] || { echo "CANN dir not found: $CANN_HOST" >&2; exit 2; }

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

IMAGE="pto-cann-sim:local"

echo "[1/2] Build image: $IMAGE"
docker build -t "$IMAGE" -f "$ROOT_DIR/docker/Dockerfile" "$ROOT_DIR"

echo "[2/2] Run"

TESTCASE_ARGS=()
if [[ -n "$TESTCASES" ]]; then
  TESTCASE_ARGS=("$TESTCASES")
fi

docker run --rm -it \
  -v "$ROOT_DIR:/work" \
  -v "$CANN_HOST:/opt/cann:ro" \
  -e CANN=/opt/cann \
  -e SOC="$SOC" \
  -e DEVICE_ID="$DEVICE_ID" \
  "$IMAGE" \
  bash -lc "scripts/run_all.sh '$MODE' ${TESTCASE_ARGS[*]:-}"

