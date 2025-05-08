#!/bin/bash

set -e

cd "$(realpath "$(dirname "$(readlink -f "$0")")")"

if [[ " $@ " =~ ' -p ' ]]; then
    docker compose pull &
    docker pull busybox:latest &
    docker pull docker/dockerfile:labs &
    docker pull kikikanri/node:24-alpine &
    docker pull oven/bun:slim &
    wait
fi

COMPOSE_BAKE=true docker compose build
docker compose up -d --remove-orphans
