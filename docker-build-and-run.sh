#!/bin/bash

set -e

if [[ "$*" == *'-p'* ]]; then
    docker compose pull &
    docker pull busybox:latest &
    docker pull docker/dockerfile:labs &
    docker pull kikikanri/node:22-alpine &
    docker pull oven/bun:slim &
    wait
fi

COMPOSE_BAKE=true docker compose build
docker compose up -d --remove-orphans
