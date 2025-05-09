#!/bin/bash

set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd "$SCRIPT_DIR"

set +e

SCRIPT_NAME='upgrade-dependencies.sh'

find . -type f -name "$SCRIPT_NAME" | while read -r file; do
    dir="$(dirname "$(realpath "$file")")"
    echo "Executing $SCRIPT_NAME in $dir ..."

    (
        cd "$dir" || continue

        if [[ -x "$SCRIPT_NAME" ]]; then
            ./"$SCRIPT_NAME"
        elif [[ -f "$SCRIPT_NAME" ]]; then
            bash "$SCRIPT_NAME"
        fi
    )
done
