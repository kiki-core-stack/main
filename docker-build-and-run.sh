#!/bin/bash

if [ "$1" = '-p' ]; then
    docker compose pull &&
        docker pull busybox:latest &&
        docker pull kikikanri/node22:base-alpine &&
        docker pull node:22-alpine &&
        docker pull oven/bun:alpine
fi

docker compose build && docker compose up -d --remove-orphans
