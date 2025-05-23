#!/bin/bash

set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd "${SCRIPT_DIR}"

git fetch https://github.com/kiki-core-stack/main main
git merge FETCH_HEAD
