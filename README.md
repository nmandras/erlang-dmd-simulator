# erlang-dmd-simulator

A TCP client/server simulator, written in Erlang/OTP, of a management agent for
an arbitrary fleet of physical devices ("routers"). It bundles both halves so it
runs end-to-end with no external systems:

- a **device fleet** — each device has a unique 15-digit IMEI, its own loopback
  IP and a listening port. A device is both a TCP *client* (sends periodic status
  CALLs) and a TCP *server* (answers commands such as `STAT` and `REBOOT`);
- a **mock management server** — receives CALLs into a registry and issues
  commands back to individual devices by IMEI.

## Wire protocol

Every message is length-prefixed: the first **2 bytes are the payload length,
least-significant byte first**, followed by the payload bytes.

```
<<Len:16/little, Payload:Len/binary>>
```

**Requests**

| Direction        | Payload                              |
|------------------|--------------------------------------|
| device → server  | `CALL: <15-digit-IMEI>,<own-ip>`     |
| server → device  | `STAT`                               |
| server → device  | `REBOOT`                             |

**Responses** — every request is answered by the peer with the command name, a
result code (`0` = success, `1` = failure) and optional data after a comma:

| Example response               | Meaning                                  |
|--------------------------------|------------------------------------------|
| `CALL:0`                       | CALL accepted                            |
| `REBOOT:0`                     | reboot acknowledged                      |
| `STAT:0,imei=…;state=running…` | status, with payload                     |
| `STAT:1,rebooting`             | command failed (device is rebooting)     |

## Architecture

Single OTP application `dmd`:

```
dmd_sup (one_for_one)
├── mgmt_sup (one_for_one)
│   ├── mgmt_registry     gen_server + ETS: IMEI -> #{ip, port, status, calls, …}
│   ├── mgmt_commander    dials devices to send STAT/REBOOT
│   └── mgmt_listener     listen socket + acceptor; ingests CALLs
└── device_sup (simple_one_for_one, dynamic fleet)
    └── device_instance_sup (one_for_all, per device)
        ├── device_agent     gen_statem (running|rebooting) + periodic CALL client
        └── device_listener  listen socket + acceptor; serves commands
```

- `dmd_proto` — framing, encode/decode (shared by both sides, unit-tested).
- `dmd_transport` — thin abstraction over `gen_tcp`/`ssl`; sockets are tagged
  `{gen_tcp, S} | {ssl, S}` so all callers are transport-agnostic.
- `dmd_config` — typed access to application environment.
- `device_cmd` — command dispatcher; `STAT`/`REBOOT` implemented, with stubbed,
  wired-in handlers for security logs / config apply / firmware upgrade.

Reboot is modelled as a `gen_statem` transition: a `REBOOT` moves the device to
`rebooting`, which pauses CALLs and fails commands with code `1` until the
configured duration elapses, then returns to `running`.

## Requirements

- Erlang/OTP 24+ and `rebar3`.
- **Linux**: the whole `127.0.0.0/8` block routes to loopback, so devices bind
  `127.0.0.2`, `127.0.0.3`, … with no setup. On **macOS** add each alias first,
  e.g. `sudo ifconfig lo0 alias 127.0.0.2 up`.

## Build & test

```sh
rebar3 compile
rebar3 eunit    # protocol unit tests
rebar3 ct       # integration (plain TCP) + TLS end-to-end
```

## Run it

```sh
rebar3 shell
```

```erlang
dmd:start_fleet(3).            %% 3 devices on 127.0.0.2..4:6000
timer:sleep(1500).
dmd:list_devices().           %% registry snapshot; each shows calls > 0
[IMEI | _] = [maps:get(imei, D) || D <- dmd:list_devices()].
dmd:send_command(IMEI, stat).   %% {ok, {<<"STAT">>, 0, <<"imei=…">>}}
dmd:send_command(IMEI, reboot). %% {ok, {<<"REBOOT">>, 0, <<>>}}; CALLs pause ~5s
dmd:start_device(<<"123456789012345">>).  %% add one more, auto IP
dmd:stop_device(IMEI).
```

## TLS (optional)

TLS is off by default. To enable it for the management server, the device
listeners and all client connections:

```sh
./priv/certs/gen_certs.sh                       # self-signed cert + key
rebar3 shell --config config/sys.tls.config
```

`config/sys.tls.config` shows the shape: `{tls, true}` plus `tls_opts` carrying
`listen` options (`certfile`/`keyfile`) and `connect` options. For real CAs use
`{verify, verify_peer}` with `{cacertfile, …}` instead of `{verify, verify_none}`.

## Configuration

All settings live under the `dmd` application env (see `config/sys.config`):
`mgmt_host`, `mgmt_port`, `device_port`, `device_ip_first_octet`,
`call_interval_ms`, `reboot_duration_ms`, `tls`, `tls_opts`.
