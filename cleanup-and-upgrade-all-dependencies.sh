#!/bin/bash

set -e

cd "$(realpath "$(dirname "$(readlink -f "$0")")")"

find . \
    \( -name '.cache' \
    -o -name '.nitro' \
    -o -name '.nuxt' \
    -o -name '.output' \
    -o -name 'dist' \
    -o -name 'node_modules' \
    \) \
    -type d \
    -prune \
    -exec rm -rf {} +

find . \
    \( -name 'bun.lock' \
    -o -name 'bun.lockb' \
    -o -name 'pnpm-lock.yaml' \
    \) \
    -type f \
    -delete

./upgrade-all-dependencies.sh
./modify-files-permissions.sh
