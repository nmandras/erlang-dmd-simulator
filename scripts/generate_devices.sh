#!/usr/bin/env bash
# Generate config/devices.csv via dmd_csv (see scripts/generate_devices.escript).
#
# Usage:  ./scripts/generate_devices.sh WMR WME [extra escript args...]
# Example: ./scripts/generate_devices.sh 8 2
#          ./scripts/generate_devices.sh 0 10 -o config/devices.csv

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/generate_devices.escript"

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 WMR WME [options...]" >&2
    exit 1
fi

if [ ! -f "$ROOT/_build/default/lib/dmd_common/ebin/dmd_csv.beam" ]; then
    echo ">> Compiling dmd_common ..."
    ( cd "$ROOT" && rebar3 compile )
fi

exec escript "$SCRIPT" "$@"
