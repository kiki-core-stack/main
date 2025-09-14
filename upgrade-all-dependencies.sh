#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${SCRIPTS_DIR}"

SCRIPT_NAME='upgrade-dependencies.sh'

find . -type f -name "${SCRIPT_NAME}" | while read -r file; do
    dir="$(dirname "$(realpath "${file}")")"
    echo "Executing ${SCRIPT_NAME} in ${dir} ..."

    (
        cd "${dir}" || continue

        if [[ -x "${SCRIPT_NAME}" ]]; then
            ./"${SCRIPT_NAME}"
        elif [[ -f "${SCRIPT_NAME}" ]]; then
            bash "${SCRIPT_NAME}"
        fi
    )
done
