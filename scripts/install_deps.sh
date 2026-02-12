#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash scripts/install_deps.sh

What it does:
  - Installs Docker (Debian/Ubuntu via apt)
  - Starts/enables Docker service
  - Validates docker CLI access

Notes:
  - This script may require sudo.
  - CANN/Simulator cannot be installed here and must be provided separately.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

note() {
  echo "[deps] $*"
}

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "missing command in PATH: $cmd"
}

require_sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    die "need root privileges but sudo is not available"
  fi
}

install_docker_debian() {
  require_sudo
  note "install docker via apt (docker.io)"
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends docker.io

  note "enable/start docker service"
  sudo systemctl enable --now docker || true
}

check_docker_access() {
  need_cmd docker

  if docker version >/dev/null 2>&1; then
    note "docker is ready"
    return
  fi

  if docker version 2>&1 | grep -qi "permission denied"; then
    die "docker permission denied. Try: sudo usermod -aG docker $USER && newgrp docker (or re-login)"
  fi

  die "docker is installed but not usable. Check docker daemon/service status."
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  need_cmd bash
  need_cmd uname

  if command -v docker >/dev/null 2>&1; then
    note "docker already installed"
  else
    if [[ -f /etc/os-release ]]; then
      # shellcheck disable=SC1091
      source /etc/os-release
      case "${ID:-}" in
        ubuntu|debian)
          install_docker_debian
          ;;
        *)
          die "unsupported OS for auto-install (ID=${ID:-unknown}). Please install Docker manually."
          ;;
      esac
    else
      die "cannot detect OS (missing /etc/os-release). Please install Docker manually."
    fi
  fi

  check_docker_access

  note "done"
}

main "$@"
