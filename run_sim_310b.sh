#!/usr/bin/env bash
set -euo pipefail

# Ascend310B simulator-based validation runner.
#
# What it does:
#   1) Build AICore binary for Ascend310B (ccec)
#   2) Build host runner (g++)
#   3) Setup simulator runtime (CA/PV)
#   4) Launch kernel and verify output (PASS/FAIL)

MODE="${1:-ca}" # ca (camodel) or pv (pvmodel)
SOC="${SOC:-Ascend310B1}"
DEVICE_ID="${DEVICE_ID:-0}"
KERNEL_RE="${KERNEL_RE:-^vec_add_scalar_kernel_2d}"

if [[ -z "${CANN:-}" ]]; then
  if [[ -n "${ASCEND_HOME_PATH:-}" ]]; then
    CANN="$ASCEND_HOME_PATH"
  else
    CANN="$HOME/miniconda3/envs/cann850/Ascend/cann-8.5.0"
  fi
fi

SIM_HOME="$CANN/x86_64-linux/simulator"

if [[ ! -f "$CANN/set_env.sh" ]]; then
  echo "ERROR: cannot find $CANN/set_env.sh" >&2
  exit 2
fi

source "$CANN/set_env.sh"

if [[ "$MODE" != "ca" && "$MODE" != "pv" ]]; then
  echo "Usage: bash run_sim_310b.sh [ca|pv]" >&2
  exit 2
fi

mkdir -p .tmp

export ASCEND_PROCESS_LOG_PATH="$PWD/.tmp/ascend_log"
export CAMODEL_LOG_PATH="$PWD/.tmp/camodel_dump"
mkdir -p "$ASCEND_PROCESS_LOG_PATH" "$CAMODEL_LOG_PATH"

# ACL loads libruntime.so; on simulator we bridge it to libruntime_camodel.so / libruntime_cmodel.so.
mkdir -p .tmp/simlib
if [[ "$MODE" == "ca" ]]; then
  ln -sf "$SIM_HOME/$SOC/lib/libruntime_camodel.so" .tmp/simlib/libruntime.so
else
  ln -sf "$SIM_HOME/$SOC/lib/libruntime_cmodel.so" .tmp/simlib/libruntime.so
fi

if [[ ! -d "$SIM_HOME/$SOC" ]]; then
  echo "ERROR: simulator soc not found: $SIM_HOME/$SOC" >&2
  echo "       try: export SOC=Ascend310B1 (or another SoC under $SIM_HOME)" >&2
  exit 2
fi
if [[ ! -f "$SIM_HOME/$SOC/lib/libruntime_camodel.so" || ! -f "$SIM_HOME/$SOC/lib/libruntime_cmodel.so" ]]; then
  echo "ERROR: simulator runtime libs not found under: $SIM_HOME/$SOC/lib" >&2
  exit 2
fi

export LD_LIBRARY_PATH="$PWD/.tmp/simlib:$SIM_HOME/$SOC/lib:$SIM_HOME/common/data:$CANN/lib64:${LD_LIBRARY_PATH:-}"

INC1="$CANN/include"
INC2="$CANN/include/pto"
LIB="$CANN/lib64"

echo "[1/4] Build device binary for $SOC ($MODE)"
ccec -c -O2 -std=c++17 kernel.cpp \
  -I. -I"$INC1" -I"$INC2" \
  --cce-aicore-arch=cce-aicore-only --cce-aicore-only \
  --cce-soc-version="$SOC" --cce-soc-core-type=AiCore \
  --cce-enable-pto-passes \
  -o .tmp/vec_add_310b.o

echo "[2/4] Detect kernel entry symbol"
OBJDUMP_BIN="${OBJDUMP_BIN:-}"
if [[ -z "$OBJDUMP_BIN" ]]; then
  if command -v llvm-objdump >/dev/null 2>&1; then
    OBJDUMP_BIN="llvm-objdump"
  elif command -v objdump >/dev/null 2>&1; then
    OBJDUMP_BIN="objdump"
  else
    echo "ERROR: cannot find llvm-objdump/objdump in PATH" >&2
    exit 2
  fi
fi

KERNEL_SYM="$("$OBJDUMP_BIN" -t .tmp/vec_add_310b.o | awk '{print $NF}' | grep -E "$KERNEL_RE" | head -n 1)"
if [[ -z "$KERNEL_SYM" ]]; then
  echo "ERROR: cannot detect kernel symbol via regex: $KERNEL_RE" >&2
  echo "       set KERNEL_SYM=... or KERNEL_RE=... to override" >&2
  exit 3
fi
echo "      kernel symbol: $KERNEL_SYM"

echo "[3/4] Build host runner"
TMPDIR="$PWD/.tmp" g++ -O2 -std=gnu++17 main_acl.cpp \
  -I"$INC1" \
  -L"$LIB" -lascendcl -lpthread -ldl \
  -o .tmp/run_310b_sim

echo "[4/4] Run simulator and validate"
.tmp/run_310b_sim .tmp/vec_add_310b.o "$KERNEL_SYM" "$DEVICE_ID"
