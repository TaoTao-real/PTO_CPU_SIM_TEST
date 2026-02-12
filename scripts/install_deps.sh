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

is_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

have_sudo() {
  command -v sudo >/dev/null 2>&1
}

run_root() {
  if is_root; then
    "$@"
  else
    sudo "$@"
  fi
}

need_root_or_sudo() {
  if is_root; then
    return
  fi
  if ! have_sudo; then
    die "need root privileges but sudo is not available (re-run as root or install sudo manually)"
  fi
}

need_apt() {
  command -v apt-get >/dev/null 2>&1 || die "apt-get not found; this auto-installer only supports Ubuntu/Debian"
}

apt_install() {
  need_apt
  need_root_or_sudo
  run_root apt-get update
  run_root apt-get install -y --no-install-recommends "$@"
}

ensure_sudo() {
  if is_root && ! have_sudo; then
    note "sudo not found; installing sudo"
    apt_install sudo
  fi
}

install_docker_debian() {
  need_root_or_sudo
  ensure_sudo
  note "install docker via apt (docker.io)"
  apt_install docker.io

  if ! command -v usermod >/dev/null 2>&1; then
    note "usermod not found; installing passwd package"
    apt_install passwd
  fi

  note "enable/start docker service"
  if command -v systemctl >/dev/null 2>&1; then
    run_root systemctl enable --now docker || run_root systemctl start docker || true
  elif command -v service >/dev/null 2>&1; then
    run_root service docker start || true
  else
    note "cannot find systemctl/service; please ensure docker daemon is running"
  fi
}

check_docker_access() {
  need_cmd docker

  if docker version >/dev/null 2>&1; then
    note "docker is ready"
    return
  fi

  local out
  out="$(docker version 2>&1 || true)"

  if echo "$out" | grep -qi "permission denied"; then
    if ! is_root && have_sudo; then
      note "docker permission denied; try to add user '$USER' to docker group"
      run_root usermod -aG docker "$USER" || true
      die "docker group updated; re-login or run: newgrp docker"
    fi
    die "docker permission denied (try running as root or fix docker group permissions)"
  fi

  if echo "$out" | grep -qi "cannot connect to the docker daemon\|is the docker daemon running"; then
    note "docker daemon not reachable; try to start service"
    if command -v systemctl >/dev/null 2>&1; then
      run_root systemctl start docker || true
    elif command -v service >/dev/null 2>&1; then
      run_root service docker start || true
    fi
    if docker version >/dev/null 2>&1; then
      note "docker is ready"
      return
    fi
  fi

  die "docker is installed but not usable. Output:\n$out"
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
