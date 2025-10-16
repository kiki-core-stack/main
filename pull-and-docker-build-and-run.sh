#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${SCRIPTS_DIR}"

find . -name '.git' -prune -type d | while read -r dir; do
    cd "$dir"/../
    git pull
    cd "${SCRIPTS_DIR}"
done

./docker-build-and-run.sh -p
