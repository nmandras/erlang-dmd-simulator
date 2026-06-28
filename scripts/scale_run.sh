#!/usr/bin/env bash
# Compile and run the scale test. Defaults to 10000 devices for 40s.
# Needs a high open-file limit; prefer scripts/docker_scale.sh, or run:
#   ulimit -n 1048576 && ./scripts/scale_run.sh 10000 40 10
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
rebar3 compile >/dev/null
exec escript scripts/scale_run.escript "$@"
