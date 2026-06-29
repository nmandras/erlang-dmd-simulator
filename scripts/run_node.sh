#!/usr/bin/env bash
# Start both applications (agent + management server) in one long-running node,
# using config/sys.config and config/devices.csv. Stays up until the container
# is stopped — used as the default command for the docker-compose `dmd` service.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
rebar3 compile >/dev/null

exec erl -noshell \
  -pa _build/default/lib/*/ebin \
  -config config/sys \
  -eval 'application:ensure_all_started(dmd_mgmt), application:ensure_all_started(dmd_agent).'
