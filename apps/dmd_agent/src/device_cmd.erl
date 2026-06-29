%%% @doc Command dispatcher for a running device.
%%%
%%% Each handler returns `{Code, Payload, Action}': Code is the result code for
%%% local logging/metrics (0 ok / 1 fail), Payload is the exact response bytes
%%% sent back to the server, and Action tells the agent whether to change state
%%% (e.g. begin a reboot).
%%%
%%% STAT replies with a rich, modem-style status dump (see {@link stat_payload/1}).
%%% REBOOT is implemented; security logs / config apply / firmware upgrade are
%%% stubbed but wired in.
-module(device_cmd).

-export([handle/2]).

-type code() :: 0 | 1.
-type action() :: none | reboot.
-export_type([code/0, action/0]).

-spec handle(term(), map()) -> {code(), binary(), action()}.
handle(stat, Data) ->
    {0, stat_payload(Data), none};
handle(reboot, _Data) ->
    {0, dmd_proto:encode_response(reboot, 0), reboot};
handle({config, _Payload}, _Data) ->
    {0, dmd_proto:encode_response(<<"CONFIG">>, 0, <<"config-applied">>), none};
handle({firmware, _Payload}, _Data) ->
    {0, dmd_proto:encode_response(<<"FIRMWARE">>, 0, <<"firmware-staged">>), none};
handle(seclog, _Data) ->
    {0, seclog_payload(), none};
handle({unknown, _Raw}, _Data) ->
    {1, dmd_proto:encode_response(<<"ERR">>, 1, <<"unknown-command">>), none}.

%%====================================================================
%% STAT response
%%====================================================================

%% Build a modem-style STAT response. Radio parameters (RSSI/SINR/RSRQ/RSRP)
%% are randomised within typical LTE ranges; RTC is the current system time and
%% UPTIME is the simulated device's uptime in seconds.
-spec stat_payload(map()) -> binary().
stat_payload(#{imei := IMEI, boot_time := Bt}) ->
    Uptime = erlang:system_time(second) - Bt,
    Rssi = -(50 + rand:uniform(60)),   %% -51 .. -110 dBm
    Sinr = rand:uniform(30),           %%   1 .. 30  dB
    Rsrq = -(3 + rand:uniform(17)),    %%  -4 .. -20 dB
    Rsrp = -(70 + rand:uniform(50)),   %% -71 .. -120 dBm
    Lines = [
        <<"STAT:smp.firmware_version = 5.3.61.0">>,
        iolist_to_binary(
          io_lib:format("smp.os_version = EC200A EC200AEUHAR01A30M16 OPERATOR=21601 "
                        "NET=21601,7 STATUS=1 IP=172.31.158.137 RSSI=~b TXPWR=0 "
                        "CID=71937 SINR=~b ECIO=0 RSRQ=~b RSRP=~b",
                        [Rssi, Sinr, Rsrq, Rsrp])),
        <<"smp.revision_id = WM-E1S WM-E1S 3.2.6">>,
        <<"smp.modem_sn = 142588346492215954">>,
        <<"smp.modem_imei = ", IMEI/binary, ", ICC = 8936200000550566520F">>,
        <<"smp.sim_imsi = 216012055056652">>,
        <<"smp.vendor = WM Systems LLC.">>,
        <<"smp.lte_bands = 3">>,
        <<"smp.battery = 4200, CAPACITY = 100">>,
        <<"smp.engineID = 0x8000CBCE03", (engine_hex(IMEI))/binary>>,
        <<"emeter.ca.validity = 2026-05-19 08:38:07;2032-08-06 15:24:56">>,
        <<"config.ca.validity = 2026-05-19 08:38:07;2032-08-06 15:24:56">>,
        <<"crl.validity = 0000-00-00 00:00:00;0000-00-00 00:00:00">>,
        <<"RTC:", (rtc_now())/binary>>,
        iolist_to_binary(io_lib:format("UPTIME:~.2f", [float(Uptime)])),
        secstat_line()
    ],
    iolist_to_binary(lists:join(<<"\n">>, Lines)).

%% SECSTAT is 1 (security events pending) with the configured probability,
%% otherwise 0. The server uses SECSTAT:1 to decide whether to fetch SECLOG.
secstat_line() ->
    P = dmd_config:get(dmd_agent, secstat_probability, 1.0),
    Value = case rand:uniform() =< P of true -> 1; false -> 0 end,
    <<"SECSTAT:", (integer_to_binary(Value))/binary>>.

%%====================================================================
%% SECLOG response
%%====================================================================

%% A SECLOG response is 1..5 randomly generated syslog (RFC3164-style) lines,
%% each with a random security event, joined by newlines under the SECLOG: tag.
-spec seclog_payload() -> binary().
seclog_payload() ->
    N = rand:uniform(5),
    Lines = [syslog_line() || _ <- lists:seq(1, N)],
    iolist_to_binary([<<"SECLOG:">>, lists:join(<<"\n">>, Lines)]).

syslog_line() ->
    Pri = rand:uniform(191),
    {{_Y, Mo, D}, {H, Mi, S}} = calendar:local_time(),
    {Tag, Msg} = random_event(),
    Pid = rand:uniform(30000),
    iolist_to_binary(
      io_lib:format("<~b>~s ~2.. b ~2..0b:~2..0b:~2..0b WM-E1S ~s[~b]: ~s",
                    [Pri, month(Mo), D, H, Mi, S, Tag, Pid, Msg])).

random_event() ->
    Events = [
        {<<"tamper">>,  <<"enclosure cover opened">>},
        {<<"tamper">>,  <<"magnetic tamper detected">>},
        {<<"meter">>,   <<"meter cover tamper switch triggered">>},
        {<<"auth">>,    <<"authentication failure for user admin">>},
        {<<"auth">>,    <<"successful login from 10.0.0.5">>},
        {<<"sshd">>,    <<"invalid user root from 192.0.2.10">>},
        {<<"kernel">>,  <<"watchdog reset detected">>},
        {<<"sec">>,     <<"certificate validation succeeded">>},
        {<<"sec">>,     <<"firmware signature verified">>},
        {<<"sec">>,     <<"unauthorized configuration change blocked">>},
        {<<"power">>,   <<"power loss event recorded">>}
    ],
    lists:nth(rand:uniform(length(Events)), Events).

month(M) ->
    element(M, {"Jan","Feb","Mar","Apr","May","Jun",
               "Jul","Aug","Sep","Oct","Nov","Dec"}).

%% A plausible engine-id hex tail derived from the IMEI.
engine_hex(IMEI) ->
    integer_to_binary(binary_to_integer(IMEI), 16).

%% Current local time as RFC3339, e.g. "2026-06-29T17:22:50+02:00".
rtc_now() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:local_time(),
    iolist_to_binary(
      io_lib:format("~4..0b-~2..0b-~2..0bT~2..0b:~2..0b:~2..0b~s",
                    [Y, Mo, D, H, Mi, S, offset_str()])).

offset_str() ->
    Local = calendar:datetime_to_gregorian_seconds(calendar:local_time()),
    Univ = calendar:datetime_to_gregorian_seconds(calendar:universal_time()),
    Diff = Local - Univ,
    Sign = case Diff < 0 of true -> "-"; false -> "+" end,
    Abs = abs(Diff),
    io_lib:format("~s~2..0b:~2..0b", [Sign, Abs div 3600, (Abs rem 3600) div 60]).
