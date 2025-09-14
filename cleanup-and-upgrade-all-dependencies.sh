#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${SCRIPTS_DIR}"

find . \
    \( -name .cache \
    -o -name .nitro \
    -o -name .nuxt \
    -o -name .output \
    -o -name dist \
    -o -name node_modules \
    \) \
    -type d \
    -prune \
    -exec rm -rf {} +

find . \
    \( -name bun.lock \
    -o -name bun.lockb \
    -o -name pnpm-lock.yaml \
    \) \
    -type f \
    -delete

./upgrade-all-dependencies.sh
./modify-files-permissions.sh
