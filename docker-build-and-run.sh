#!/bin/bash

if [ "$1" = "-p" ]; then
	docker compose pull &&
		docker pull alpine:latest &&
		docker pull busybox:latest &&
		docker pull kikikanri/node22:base-alpine &&
		docker pull node:22-alpine
fi

docker compose build && docker compose up -d --remove-orphans
