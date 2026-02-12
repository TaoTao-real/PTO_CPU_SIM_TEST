#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash docker/run_docker.sh [--cann /abs/path/to/cann] [--mode ca|pv] [--soc Ascend310B1] [--device 0] [--testcases testcases]
  bash docker/run_docker.sh --build-only [--cann /abs/path/to/cann]

Notes:
  - This builds a local Docker image that contains only the open-source toolchain.
  - CANN is mounted at runtime (not copied into the image).
  - If --cann is omitted, it tries (in order): $CANN_HOST, ./.cann_path, $CANN, $ASCEND_HOME_PATH, default path.
  - Use --save-cann to persist the detected host CANN path to ./.cann_path (ignored by git).
EOF
}

MODE="ca"
SOC="Ascend310B1"
DEVICE_ID="0"
TESTCASES=""
CANN_HOST_DIR=""
IMAGE="pto-cann-sim:local"
BUILD_ONLY=0
SAVE_CANN=0

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CANN_PATH_FILE="$ROOT_DIR/.cann_path"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found in PATH" >&2
  echo "       try: bash scripts/install_deps.sh" >&2
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cann)
      CANN_HOST_DIR="${2:-}"; shift 2 ;;
    --mode)
      MODE="${2:-}"; shift 2 ;;
    --soc)
      SOC="${2:-}"; shift 2 ;;
    --device)
      DEVICE_ID="${2:-}"; shift 2 ;;
    --testcases)
      TESTCASES="${2:-}"; shift 2 ;;
    --image)
      IMAGE="${2:-}"; shift 2 ;;
    --build-only)
      BUILD_ONLY=1; shift ;;
    --save-cann)
      SAVE_CANN=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

detect_cann_host_dir() {
  if [[ -n "$CANN_HOST_DIR" ]]; then
    echo "$CANN_HOST_DIR"
    return
  fi
  if [[ -n "${CANN_HOST:-}" ]]; then
    echo "$CANN_HOST"
    return
  fi
  if [[ -f "$CANN_PATH_FILE" ]]; then
    local p
    p="$(head -n 1 "$CANN_PATH_FILE" | tr -d '\r' | xargs || true)"
    if [[ -n "$p" ]]; then
      echo "$p"
      return
    fi
  fi
  if [[ -n "${CANN:-}" ]]; then
    echo "$CANN"
    return
  fi
  if [[ -n "${ASCEND_HOME_PATH:-}" ]]; then
    echo "$ASCEND_HOME_PATH"
    return
  fi
  echo "$HOME/miniconda3/envs/cann850/Ascend/cann-8.5.0"
}

CANN_HOST_DIR="$(detect_cann_host_dir)"
[[ -n "$CANN_HOST_DIR" ]] || { echo "ERROR: cannot detect host CANN path (use --cann ...)" >&2; exit 2; }
[[ -d "$CANN_HOST_DIR" ]] || { echo "ERROR: CANN dir not found: $CANN_HOST_DIR" >&2; exit 2; }

if [[ "$SAVE_CANN" -eq 1 ]]; then
  printf '%s\n' "$CANN_HOST_DIR" >"$CANN_PATH_FILE"
  echo "[info] saved host CANN path to: $CANN_PATH_FILE"
fi

echo "[1/2] Build image: $IMAGE"
docker build -t "$IMAGE" -f "$ROOT_DIR/docker/Dockerfile" "$ROOT_DIR"

if [[ "$BUILD_ONLY" -eq 1 ]]; then
  echo "[done] build-only"
  exit 0
fi

echo "[2/2] Run"

TESTCASE_ARGS=()
if [[ -n "$TESTCASES" ]]; then
  TESTCASE_ARGS=("$TESTCASES")
fi

docker run --rm -it \
  -v "$ROOT_DIR:/work" \
  -v "$CANN_HOST_DIR:/opt/cann:ro" \
  -e CANN=/opt/cann \
  -e SOC="$SOC" \
  -e DEVICE_ID="$DEVICE_ID" \
  "$IMAGE" \
  bash -lc "scripts/run_all.sh '$MODE' ${TESTCASE_ARGS[*]:-}"
