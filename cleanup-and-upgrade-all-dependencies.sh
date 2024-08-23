#!/bin/bash

cd $(dirname "$(readlink -f "$0")")
find . -name .nitro -type d -prune -exec rm -rf '{}' \;
find . -name .nuxt -type d -prune -exec rm -rf '{}' \;
find . -name .output -type d -prune -exec rm -rf '{}' \;
find . -name bun.lockb -type f -prune -exec rm '{}' \;
find . -name dist -type d -prune -exec rm -rf '{}' \;
find . -name pnpm-lock.yaml -type f -prune -exec rm '{}' \;
find . -name node_modules -type d -prune -exec rm -rf '{}' \;
./upgrade-all-dependencies.sh