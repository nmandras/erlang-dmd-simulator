#!/usr/bin/env bash
# Build the image and run the scale test in a container tuned for many
# short-lived connections. Logs are written to ./log on the host via a mount.
#
# Usage: ./scripts/docker_scale.sh [Wmr] [Wme] [DurationSec] [PeriodSec]
#   (defaults: 8000 wmr + 2000 wme, 40s, 10s period)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${IMAGE:-dmd-sim:latest}"
WMR="${1:-8000}"
WME="${2:-2000}"
DUR="${3:-40}"
PERIOD="${4:-10}"

docker build -t "$IMAGE" "$ROOT"
mkdir -p "$ROOT/log"

# --ulimit nofile : one listen socket per device (+ transient connections)
# --sysctl ...port_range / tcp_tw_reuse : avoid ephemeral-port exhaustion under
#   the steady stream of short-lived CALL/command connections.
docker run --rm \
  --ulimit nofile=1048576:1048576 \
  --sysctl net.ipv4.ip_local_port_range="1024 65535" \
  --sysctl net.ipv4.tcp_tw_reuse=1 \
  -v "$ROOT/log:/app/log" \
  "$IMAGE" ./scripts/scale_run.sh "$WMR" "$WME" "$DUR" "$PERIOD"

echo
echo "Scale logs written to:"
echo "  $ROOT/log/agent_scale.log"
echo "  $ROOT/log/mgmt_scale.log   (metrics reports are at the end of each)"
