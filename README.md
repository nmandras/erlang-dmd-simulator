# erlang-dmd-simulator

A TCP client/server simulator, in Erlang/OTP, of a management agent for an
arbitrary fleet of physical devices ("routers"). It is split into **two runnable
OTP applications** sharing a common library:

| Application  | Role                                                                 |
|--------------|----------------------------------------------------------------------|
| `dmd_agent`  | The device fleet. Each device is a TCP *client* (periodic status CALLs) and a TCP *server* (answers `STAT`/`REBOOT`). |
| `dmd_mgmt`   | The mock management server. Ingests CALLs, and autonomously drives random commands to devices. |
| `dmd_common` | Shared library: wire protocol, transport, config, CSV, logging.      |

Both applications read the same **device inventory CSV** (`imei,ip,port,callperiod`),
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

**Responses** — every request is answered with the command name, a result code
(`0` success, `1` failure) and optional data after a comma:

| Example                        | Meaning                              |
|--------------------------------|--------------------------------------|
| `CALL:0`                       | CALL accepted                        |
| `REBOOT:0`                     | reboot acknowledged                  |
| `STAT:0,imei=…;state=running…` | status, with payload                 |
| `STAT:1,rebooting`             | failed (device is rebooting)         |

## Device inventory CSV

`config/devices.csv` ships with 10 devices, IMEIs `101000000000001`…`101000000000010`,
loopback IPs `127.0.0.2`…`127.0.0.11`, port `6000`, and a `10`-second call period:

```
imei,ip,port,callperiod
101000000000001,127.0.0.2,6000,10
...
```

`callperiod` is in seconds. Regenerate it from the shell with
`dmd_csv:generate_file("config/devices.csv", 10).`

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

The autonomous driver (`mgmt_driver`) picks a random device every
`driver_min_ms`…`driver_max_ms` and sends a random command (mostly `STAT`,
~1-in-4 `REBOOT`). Disable it with `{driver_enabled, false}`.

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
agent-only `reboot_duration_ms`; server-only `driver_enabled`, `driver_min_ms`,
`driver_max_ms`.
