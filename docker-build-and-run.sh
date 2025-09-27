#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${SCRIPTS_DIR}"

if [[ " $@ " =~ ' -p ' ]]; then
    docker compose pull &
    docker pull busybox:latest &
    docker pull docker/dockerfile:labs &
    docker pull oven/bun:slim &
    wait
fi

docker compose up -d --build --remove-orphans
