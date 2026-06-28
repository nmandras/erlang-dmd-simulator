#!/usr/bin/env bash
# Build the image and run the full test suite (eunit + ct) in a container,
# with a raised file-descriptor limit.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${IMAGE:-dmd-sim:latest}"

docker build -t "$IMAGE" "$ROOT"
docker run --rm \
  --ulimit nofile=1048576:1048576 \
  "$IMAGE" rebar3 do eunit, ct
