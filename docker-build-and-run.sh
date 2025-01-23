#!/bin/bash

set -e

if [[ "$*" == *'-p'* ]]; then
    docker compose pull &
    docker pull busybox:latest &
    docker pull kikikanri/node22:base-alpine &
    docker pull oven/bun:slim &
    wait
fi

docker compose build
docker compose up -d --remove-orphans
