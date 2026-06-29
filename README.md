# erlang-dmd-simulator

A TCP client/server simulator, in Erlang/OTP, of a management agent for an
arbitrary fleet of physical devices ("routers"). It is split into **two runnable
OTP applications** sharing a common library:

| Application  | Role                                                                 |
|--------------|----------------------------------------------------------------------|
| `dmd_agent`  | The device fleet. Each device is a TCP *client* (periodic status CALLs) and a TCP *server* (answers `STAT`/`REBOOT`). |
| `dmd_mgmt`   | The mock management server. Ingests CALLs, and autonomously drives random commands to devices. |
| `dmd_common` | Shared library: wire protocol, transport, config, CSV, logging.      |
| `wme`        | WM-E (WME) protocol library: IEC handshake + config read, client and device simulator (see below). |

Both applications read the same **device inventory CSV** (with a per-device `DeviceType`),
so the agent knows which devices to spawn and the server knows where to reach them.

## Wire protocol

Every message is length-prefixed: the first **2 bytes are the payload length,
least-significant byte first**, then the payload.

```
<<Len:16/little, Payload:Len/binary>>
```

**Requests**

| Direction        | Payload                              |
|------------------|--------------------------------------|
| agent → server   | `CALL:<15-digit-IMEI>,<own-ip>`      |
| server → agent   | `STAT`                               |
| server → agent   | `REBOOT`                             |
| server → agent   | `SECLOG`                             |

**Responses** — most requests are answered with the command name, a result code
(`0` success, `1` failure) and optional data after a comma:

| Example              | Meaning                              |
|----------------------|--------------------------------------|
| `CALL:0`             | CALL accepted                        |
| `REBOOT:0`           | reboot acknowledged                  |
| `STAT:1,rebooting`   | command failed (device is rebooting) |

A successful `STAT` replies with a rich, modem-style status dump instead of a
numeric code (the `STAT:` tag introduces it, alongside the `RTC:`, `UPTIME:` and
`SECSTAT:` tags). Radio parameters (RSSI/SINR/RSRQ/RSRP) are randomised within
typical LTE ranges, `RTC` is the current system time and `UPTIME` is the
device's uptime in seconds:

```
STAT:smp.firmware_version = 5.3.61.0
smp.os_version = EC200A ... RSSI=-86 TXPWR=0 CID=71937 SINR=5 ECIO=0 RSRQ=-5 RSRP=-89
smp.modem_imei = 101000000000001, ICC = 8936200000550566520F
smp.vendor = WM Systems LLC.
smp.battery = 4200, CAPACITY = 100
...
RTC:2026-06-29T17:40:45+00:00
UPTIME:1.00
SECSTAT:1
```

The management side decodes this as `{<<"STAT">>, 0, <body>}` — a non-numeric
payload is treated as success (code 0).

A `SECLOG` request returns 1–5 randomly generated syslog (RFC3164-style)
security-event lines, joined by newlines under a `SECLOG:` tag:

```
SECLOG:<188>Jun 29 18:00:32 WM-E1S sec[21749]: certificate validation succeeded
<34>Jun 29 18:00:32 WM-E1S tamper[4021]: enclosure cover opened
```

**STAT → SECLOG chain:** a STAT body ends with `SECSTAT:1` with probability
`secstat_probability` (default `1.0`), otherwise `SECSTAT:0`. When the server's
on-CALL STAT completes and reports `SECSTAT:1`, it immediately follows up with a
`SECLOG` to fetch the device's security events. The chain shows in
`log/mgmt.log` as `cmd=stat reason=on_call` then `cmd=seclog reason=secstat`.

## Device inventory CSV

`config/devices.csv` lists the fleet, one device per row:

```
IMEI,IP,MgmtPort,PortSSH,DeviceType,TLSEnable,Reptime,LoginName,LoginPass,EquipmentGroup,Comments
101000000000001,127.10.0.1,6000,22,1,0,10,root,admin,Group-1,
101000000000009,127.10.0.9,6000,22,2,0,10,root,admin,Group-2,
```

- **DeviceType** selects the device's inbound listener: `1` = **wmr** (CALL +
  STAT/REBOOT/SECLOG text protocol), `2` = **wme** (CALL + WM-E config read).
  Every device sends the periodic CALL regardless of type.
- **MgmtPort** is the device's listen port; **Reptime** is the CALL period in
  seconds. **PortSSH**, **TLSEnable**, **LoginName**, **LoginPass**,
  **EquipmentGroup** and **Comments** are stored as metadata.

Generate one from the shell — `dmd_csv:generate_file("config/devices.csv", Wmr, Wme)`
or, with options, `dmd_csv:generate(Wmr, Wme, #{start_imei => 1, base_ip => {127,10,0,1}, mgmt_port => 6000, period_sec => 30})`.

## WME protocol (config read)

Devices whose `DeviceType` is `2` speak the **WM-E (WME) wire protocol** as a
*server* on their own IP at `MgmtPort`, and the management server acts as the
**WMETerm client**. This is a focused slice of the WM-E spec: the IEC 62056-21
identification handshake (`/?…!` → `/ELS…` → `059`) followed by a config **read**
(start-read `0x67` → header `0x68` → packet `0x70`/`0x71`), with per-frame XOR
checksums and a Fletcher-16 integrity check over the reassembled blob. (Write,
syslog, baud-change and password are out of scope in this slice; the AES
password KDF is undocumented.)

The protocol lives in the standalone `wme` library app (`wme_checksum`,
`wme_codec`, `wme_transport`, `wme_handshake`, `wme_client`, `wme_sim_device`).
On the device side, `device_wme_listener` serves a realistic per-device config
blob (`device_wme:config_blob/2`) — the usual WM-E `key = value` dump, with the
modem IMEI, engine id and signal levels derived from the device's IMEI. Read one
from the server:

```erlang
dmd_mgmt:wme_read_config(<<"101000000000009">>, config).   %% a DeviceType=2 device
%% {ok, <<"conn.apn_name = wm2m\nconn.apn_user = xxxxxxxx\n...
%%        smp.modem_imei = 101000000000009, ICC = ...\n
%%        smp.os_version = EC200A ... RSSI=-83 SINR=7 RSRQ=-9 RSRP=-101\n
%%        smp.engineID = 0x8000CBCE03000000000009\n">>}   (~3 KB, ~12 V1 packets)
```

## Architecture

```
dmd_agent (application)              dmd_mgmt (application)
└── dmd_agent_sup                    └── dmd_mgmt_sup
    └── device_sup (dynamic)             ├── mgmt_registry   ETS, loaded from CSV
        └── device_instance_sup         ├── mgmt_commander  dials devices
            ├── device_agent            ├── mgmt_listener   ingests CALLs
            │   gen_statem +            └── mgmt_driver     random commands
            │   periodic CALL client
            └── device_listener
                serves commands
```

`dmd_common` provides `dmd_proto` (framing/codec), `dmd_transport`
(`gen_tcp`/`ssl` abstraction), `dmd_config` (per-app env), `dmd_csv` (inventory),
and `dmd_log` (per-app file logging).

Reboot is a `gen_statem` transition: `REBOOT` moves a device to `rebooting`,
which pauses CALLs and fails commands with code `1` until the configured
duration elapses, then returns to `running`.

## Logging

Each application installs its own timestamped `logger` file handler:

- `log/agent.log` — every CALL **sent** and every command **received**.
- `log/mgmt.log`  — every CALL **received**, plus every autonomous **DRIVER**
  command and its result.

Example:

```
2026-06-28 09:19:57.393 info CALL recv imei=101000000000001 ip=127.0.0.2
2026-06-28 09:20:03.784 info DRIVER cmd=stat imei=101000000000006 result={<<"STAT">>,0}
```

On every CALL it receives, the server polls the calling device by issuing a
`STAT` back to it (asynchronously, so the CALL response is not delayed). These
appear in `log/mgmt.log` as `CMD send … reason=on_call` and in `log/agent.log`
as `CMD recv … cmd=stat`. Disable with `{stat_on_call, false}`.

The autonomous driver (`mgmt_driver`) picks a random device every
`driver_min_ms`…`driver_max_ms` and sends a random command (mostly `STAT`,
~1-in-4 `REBOOT`). Disable it with `{driver_enabled, false}`.

## Benchmarking metrics

Each app runs a `dmd_metrics` collector that records counters (calls, commands,
successes/failures) and timing samples (CALL and command latencies) at runtime
via fire-and-forget casts. When the app is stopped (graceful shutdown, e.g.
`Ctrl+C, a`), the collector renders an ASCII report — counter bar charts and
latency histograms — into that app's log file:

```
==================== dmd_mgmt metrics (uptime 60s) ====================
counters:
  calls_received              61 |########################################
  driver_total                10 |#######
cmd_latency_ms: n=10 min=1 avg=1.2 max=2 p95=2
   1-1     |############################## 8
   2-2     |######## 2
==================== end dmd_mgmt metrics ====================
```

`log/agent.log` and `log/mgmt.log` in this repo are a captured 60-second run.
Render a report on demand with `dmd_metrics:report(dmd_mgmt)`.

## Requirements

- Erlang/OTP 24+ and `rebar3`.
- **Linux**: `127.0.0.0/8` all routes to loopback, so devices bind
  `127.0.0.2`, `127.0.0.3`, … with no setup. On **macOS** add each alias first,
  e.g. `sudo ifconfig lo0 alias 127.0.0.2 up`.

## Build & test

```sh
rebar3 compile
rebar3 eunit    # protocol + CSV unit tests
rebar3 ct       # two-app integration (plain TCP) + TLS end-to-end
```

## Docker & scale testing

Each device binds its own listen socket, so a large fleet needs a high
open-file limit. Run everything in a container where that limit can be raised:

The scale test takes the **wmr and wme device counts** separately, so each
device type can be generated and benchmarked:

```sh
./scripts/docker_test.sh                    # build image, run eunit + ct
./scripts/docker_scale.sh                   # 8000 wmr + 2000 wme for 40s (default)
./scripts/docker_scale.sh 8000 2000 60 10   # Wmr, Wme, DurationSec, PeriodSec
```

`docker_scale.sh` runs with `--ulimit nofile=1048576` (one listen socket per
device) and widened ephemeral-port settings (`--sysctl`) to sustain the stream
of short-lived connections. It bind-mounts `./log`, so afterwards
`log/agent_scale.log` and `log/mgmt_scale.log` hold the run (each ending with
the metrics report), and the run prints a per-type summary:

- **wmr**: CALL/STAT/SECLOG counters and latency histograms.
- **wme**: a concurrent config-read benchmark — reads/s, MB/s and average
  latency (e.g. ~3000 reads/s, ~8.5 MB/s at concurrency 50).

The fleet CSV is generated with `dmd_csv:generate_scale/3`, which spreads device
IPs across the whole `127.0.0.0/8` block (so far more than 254 devices each get
a distinct, bindable loopback IP). To run directly (outside Docker) raise the
limit yourself first:

```sh
ulimit -n 1048576 && ./scripts/scale_run.sh 8000 2000 40 10
```

## Run it

```sh
rebar3 shell
```

Both applications start, the server loads the inventory, and the 10 devices
begin CALLing every 10s. Watch `log/mgmt.log` and `log/agent.log`, or drive it:

```erlang
dmd_mgmt:list_devices().                     %% fleet snapshot (calls counter rising)
dmd_mgmt:send_command(<<"101000000000001">>, stat).   %% {ok,{<<"STAT">>,0,<<"imei=…">>}}
dmd_mgmt:send_command(<<"101000000000001">>, reboot). %% {ok,{<<"REBOOT">>,0,<<>>}}
dmd_mgmt:driver_count().                     %% autonomous commands issued so far
dmd_agent:start_device(<<"101000000000011">>, {127,0,0,12}, 6000, 10000). %% add one
```

## Windows x64 build

`.beam` output is portable bytecode, so a Linux/macOS build runs on Windows x64
— only the runtime is native. Build a staged distribution with `.bat` launchers:

```sh
./scripts/build_windows_x64.sh        # -> dist/windows-x64/ and dist/dmd-windows-x64.zip
```

Copy the folder to a Windows x64 machine that has Erlang/OTP for Windows
installed (`erl` on PATH), then run `start_all.bat` (or `start_mgmt.bat` /
`start_agent.bat`). Stopping the node flushes the metrics report to `log\`.

## TLS (optional)

TLS is off by default and applies to every listener and client connection:

```sh
./priv/certs/gen_certs.sh                       # self-signed cert + key
rebar3 shell --config config/sys.tls.config
```

`config/sys.tls.config` shows the shape: per-app `{tls, true}` plus `tls_opts`
with `listen` (`certfile`/`keyfile`) and `connect` options. For a real CA use
`{verify, verify_peer}` with `{cacertfile, …}` instead of `{verify, verify_none}`.

## Configuration

Per-application `dmd_agent` / `dmd_mgmt` env keys (see `config/sys.config`):
`csv_file`, `mgmt_host`, `mgmt_port`, `log_file`, `tls`, `tls_opts`;
agent-only `call_dispatch` (`spread` | `burst`), `secstat_probability`
(`0.0`..`1.0`) and `reboot_duration_ms`; server-only `stat_on_call`,
`driver_enabled`, `driver_min_ms`, `driver_max_ms`.

`call_dispatch` controls how the fleet times its periodic CALLs: `spread`
(default) gives each device a random offset within the period so calls are
distributed evenly, while `burst` makes all devices call in step ("all at
once").
