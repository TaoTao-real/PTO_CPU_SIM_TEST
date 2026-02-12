#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/deploy_test_env.sh [--install-deps] [--cann /abs/path/to/cann] [--image pto-cann-sim:local]

What it does:
  - Optionally installs host dependencies (Docker)
  - Builds the local Docker image for this repo
  - Saves the host CANN path to ./.cann_path (gitignored)

Then you can run tests with:
  bash docker/run_docker.sh --mode ca
EOF
}

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

CANN_HOST_DIR=""
IMAGE="pto-cann-sim:local"
INSTALL_DEPS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-deps)
      INSTALL_DEPS=1; shift ;;
    --cann)
      CANN_HOST_DIR="${2:-}"; shift 2 ;;
    --image)
      IMAGE="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$INSTALL_DEPS" -eq 1 ]]; then
  bash "$ROOT_DIR/scripts/install_deps.sh"
fi

args=("--build-only" "--save-cann" "--image" "$IMAGE")
if [[ -n "$CANN_HOST_DIR" ]]; then
  args+=("--cann" "$CANN_HOST_DIR")
fi

bash "$ROOT_DIR/docker/run_docker.sh" "${args[@]}"

echo "[done] test env is ready"
echo "       next: bash docker/run_docker.sh --mode ca"
