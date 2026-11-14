#!/usr/bin/env bash

# shellcheck shell=bash
# shellcheck disable=SC1091

set -euo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/scripts/libs/common.sh"

# Constants/Variables
readonly COMPOSE_FILE_PATH="${SCRIPT_DIR}/stacks/gateway/dev/compose.yaml"
readonly ENV_FILE_PATH="${SCRIPT_DIR}/.env.development.local"

# Run
main() {
    exec docker compose --env-file "${ENV_FILE_PATH}" -f "${COMPOSE_FILE_PATH}" "$@"
}

main "$@"
