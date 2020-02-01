#!/usr/bin/env bash
set -euo pipefail

IMAGE=${IMAGE:-json-path-bash}

readonly script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}"  )" && pwd  )"
readonly RUN_ARGS="$@"
readonly target_image=$IMAGE

docker build -t "$target_image" "$script_dir"

docker run --rm -v "$(pwd):/localdir" -i "$target_image" sh -c "cd /localdir && $RUN_ARGS"

