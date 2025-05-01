#!/bin/bash

cd "$(realpath "$(dirname "$(readlink -f "$0")")")" || exit 1

SCRIPT_NAME='tmux-run-dev.sh'

find . -type f -name "$SCRIPT_NAME" | while read -r file; do
    dir="$(dirname "$file")"
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
