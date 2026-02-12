#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${CANN:-}" ]]; then
  if [[ -n "${ASCEND_HOME_PATH:-}" ]]; then
    CANN="$ASCEND_HOME_PATH"
  else
    CANN="$HOME/miniconda3/envs/cann850/Ascend/cann-8.5.0"
  fi
fi

INC1="$CANN/include"
INC2="$CANN/include/pto"

mkdir -p .tmp

TMPDIR="$PWD/.tmp" g++ -std=gnu++17 -O2 -pthread \
  -D__CPU_SIM \
  -I. -I"$INC1" -I"$INC2" \
  -include pto/common/cpu_stub.hpp \
  kernel.cpp main.cpp \
  -o pto_cpu_sim

./pto_cpu_sim
