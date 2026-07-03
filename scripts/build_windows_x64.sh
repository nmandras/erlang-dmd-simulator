#!/usr/bin/env bash
#
# Cross-build a Windows x64 distribution of the dmd simulator from Linux/macOS.
#
# Erlang's compiled output (.beam) is portable bytecode, so the same build runs
# on Windows x64 — only the runtime (ERTS) is native. This script therefore
# compiles the apps once and stages a self-contained folder with .bat launchers
# that use the Erlang/OTP for Windows x64 installed on the *target* machine
# (https://www.erlang.org/downloads — "erl" must be on PATH).
#
# Usage:  ./scripts/build_windows_x64.sh
# Output: dist/windows-x64/  (and dist/dmd-windows-x64.zip if `zip` is present)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/dist/windows-x64"
APPS=(dmd_common wme dmd_agent dmd_mgmt)

echo ">> Compiling (portable BEAM)..."
( cd "$ROOT" && rebar3 compile )

echo ">> Staging into $OUT ..."
rm -rf "$OUT"
mkdir -p "$OUT/config" "$OUT/log"

for app in "${APPS[@]}"; do
    src="$ROOT/_build/default/lib/$app/ebin"
    [ -d "$src" ] || { echo "ERROR: missing $src (compile failed?)" >&2; exit 1; }
    mkdir -p "$OUT/lib/$app/ebin"
    cp "$src"/* "$OUT/lib/$app/ebin/"
done

cp "$ROOT/config/sys.config" "$OUT/config/"
cp "$ROOT/config/sys.scale.config" "$OUT/config/" 2>/dev/null || true
cp "$ROOT/config/sys.tls.config" "$OUT/config/" 2>/dev/null || true
cp "$ROOT/config/devices.csv" "$OUT/config/"

WIN_SCRIPTS="$ROOT/scripts/windows"
if [ -d "$WIN_SCRIPTS" ]; then
    for ps1 in Dmd-Common.ps1 Start-All.ps1 Start-Mgmt.ps1 Start-Agent.ps1 \
               Add-LoopbackAliases.ps1 Set-WindowsTcpTuning.ps1 New-DeviceFleetCsv.ps1 Test-Prerequisites.ps1; do
        [ -f "$WIN_SCRIPTS/$ps1" ] && cp "$WIN_SCRIPTS/$ps1" "$OUT/"
    done
    [ -f "$WIN_SCRIPTS/generate_devices.bat" ] && cp "$WIN_SCRIPTS/generate_devices.bat" "$OUT/"
fi

[ -f "$ROOT/scripts/generate_devices.escript" ] && cp "$ROOT/scripts/generate_devices.escript" "$OUT/"

if [ -d "$ROOT/priv/certs" ]; then
    mkdir -p "$OUT/priv/certs"
    cp "$ROOT/priv/certs"/* "$OUT/priv/certs/" 2>/dev/null || true
fi

PA='-pa "%ROOT%lib\dmd_common\ebin" "%ROOT%lib\wme\ebin" "%ROOT%lib\dmd_agent\ebin" "%ROOT%lib\dmd_mgmt\ebin"'

# Shared launcher prologue: resolve the dist root and cd into it so the relative
# log/ and config/ paths in sys.config resolve correctly.
prologue() {
    printf '@echo off\r\n'
    printf 'setlocal\r\n'
    printf 'set "ROOT=%%~dp0"\r\n'
    printf 'cd /d "%%ROOT%%"\r\n'
}

echo ">> Writing .bat launchers..."

{
    prologue
    printf 'erl %s -config "%%ROOT%%config\\sys" ^\r\n' "$PA"
    printf '    -eval "application:ensure_all_started(dmd_mgmt)."\r\n'
} > "$OUT/start_mgmt.bat"

{
    prologue
    printf 'erl %s -config "%%ROOT%%config\\sys" ^\r\n' "$PA"
    printf '    -eval "application:ensure_all_started(dmd_agent)."\r\n'
} > "$OUT/start_agent.bat"

# Run both in one interactive node (Ctrl+C twice to stop; this triggers the
# metrics report to the log files on shutdown).
{
    prologue
    printf 'erl %s -config "%%ROOT%%config\\sys" ^\r\n' "$PA"
    printf '    -eval "application:ensure_all_started(dmd_mgmt), application:ensure_all_started(dmd_agent)."\r\n'
} > "$OUT/start_all.bat"

cat > "$OUT/README.txt" <<'TXT'
dmd simulator - Windows x64 distribution
========================================

Requires Erlang/OTP for Windows x64 installed, with "erl" on PATH
(https://www.erlang.org/downloads).

Before first run, add loopback aliases for device IPs (elevated PowerShell):
  powershell -ExecutionPolicy Bypass -File .\Add-LoopbackAliases.ps1
(Only if Add-LoopbackAliases.ps1 is present; otherwise use netsh manually.)

Run:
  start_all.bat     - management server + device fleet in one node
  start_mgmt.bat    - management server only
  start_agent.bat   - device fleet only

Or PowerShell launchers (if copied into this folder):
  Start-All.ps1, Start-Mgmt.ps1, Start-Agent.ps1

Logs are written under log\ (agent.log, mgmt.log). Stopping the node
(Ctrl+C, a) flushes a benchmarking report to each log file.

Edit config\sys.config to change ports, the device CSV, the call period,
or to enable TLS (see config\sys.tls.config).
TXT

if command -v unix2dos >/dev/null 2>&1; then
    unix2dos -q "$OUT/README.txt" "$OUT/config/"*.config 2>/dev/null || true
fi

if command -v zip >/dev/null 2>&1; then
    echo ">> Zipping..."
    ( cd "$ROOT/dist" && rm -f dmd-windows-x64.zip && zip -qr dmd-windows-x64.zip windows-x64 )
    echo ">> Created dist/dmd-windows-x64.zip"
fi

echo ">> Done: $OUT"
