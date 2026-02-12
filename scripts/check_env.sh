#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

MODE="${MODE:-ca}" # ca|pv
SOC="${SOC:-Ascend310B1}"
DEVICE_ID="${DEVICE_ID:-0}"

die() {
  echo "ERROR: $*" >&2
  exit 2
}

note() {
  echo "[check] $*"
}

detect_cann() {
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

CANN="$(detect_cann)"
SIM_HOME="$CANN/x86_64-linux/simulator"

note "root: $ROOT_DIR"
note "mode: $MODE, soc: $SOC, device: $DEVICE_ID"
note "cann: $CANN"

[[ -d "$ROOT_DIR" ]] || die "root dir not found: $ROOT_DIR"
[[ -f "$CANN/set_env.sh" ]] || die "cannot find $CANN/set_env.sh (set CANN=/path/to/cann)"
[[ -d "$CANN/include" ]] || die "cannot find $CANN/include"
[[ -d "$CANN/lib64" ]] || die "cannot find $CANN/lib64"

if [[ ! -d "$SIM_HOME" ]]; then
  die "cannot find simulator dir: $SIM_HOME (need x86_64 simulator in CANN)"
fi
if [[ ! -d "$SIM_HOME/$SOC" ]]; then
  die "simulator SoC not found: $SIM_HOME/$SOC (export SOC=...)"
fi
if [[ ! -f "$SIM_HOME/$SOC/lib/libruntime_camodel.so" || ! -f "$SIM_HOME/$SOC/lib/libruntime_cmodel.so" ]]; then
  die "simulator runtime libs missing under: $SIM_HOME/$SOC/lib"
fi

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "missing command in PATH: $cmd"
}

note "checking base toolchain"
need_cmd bash
need_cmd g++
need_cmd python3

note "checking CANN toolchain (after set_env.sh)"
# shellcheck disable=SC1090
source "$CANN/set_env.sh"
need_cmd ccec

if ! command -v llvm-objdump >/dev/null 2>&1 && ! command -v objdump >/dev/null 2>&1; then
  die "missing llvm-objdump/objdump (needed to detect kernel entry symbol)"
fi

note "OK"

