#!/bin/bash

cd "$(dirname "$(readlink -f "$0")")"
SCRIPT_NAME='upgrade-dependencies.sh'

execute_script() {
	local dir=$1
	(
		cd "$dir"
		echo "Executing $SCRIPT_NAME in $dir ..."
		chmod 700 "$SCRIPT_NAME"
		./"$SCRIPT_NAME"
	)
}

find . -type f -name "$SCRIPT_NAME" | while read -r file; do
	dir=$(dirname "$file")
	execute_script "$dir"
done
