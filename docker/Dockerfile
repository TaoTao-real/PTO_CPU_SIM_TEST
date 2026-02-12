FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash ca-certificates \
    build-essential \
    python3 \
    llvm \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /work

# CANN cannot be redistributed; mount it at runtime.
# Default expected mount point: /opt/cann
ENV CANN=/opt/cann
ENV SOC=Ascend310B1
ENV DEVICE_ID=0

CMD ["bash", "-lc", "scripts/run_all.sh ca"]

