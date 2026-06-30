%%% @doc Per-device WM-E config content. Generates a realistic device config
%%% blob (key = value lines, as a real WM-E modem returns for a 0xFF read) and a
%%% modem-style status blob for a 0x0D read, derived deterministically from the
%%% device IMEI.
-module(device_wme).

-export([config_blob/2, ident/1, syslog_blob/1]).

%% Provider for wme_sim_device: option byte -> blob.
-spec config_blob(binary(), byte()) -> {ok, binary()} | error.
config_blob(IMEI, 16#FF) -> {ok, full_config(IMEI)};
config_blob(IMEI, 16#0D) -> {ok, status_blob(IMEI)};
config_blob(_IMEI, _Other) -> error.

%% IEC ident line for this device (V1 chunking; no "1K"/"1024" marker), matching
%% a real WM-E1S unit: /ELS<baud>\<hw> <firmware> <hw_id>.
-spec ident(binary()) -> binary().
ident(_IMEI) ->
    <<"/ELS5\\7 V5.3.61.0 1S1P\r\n">>.

%% A realistic WM-E configuration dump. Device-specific fields (modem IMEI,
%% engine id, signal levels) are derived from the IMEI so reads are stable.
full_config(IMEI) ->
    ConfigLines = [
        <<"conn.apn_name = wm2m">>,
        <<"conn.apn_user = xxxxxxxx">>,
        <<"conn.apn_pass = xxxxxxxx">>,
        <<"tm_server.port = 9000">>,
        <<"fw_server.port = 9001">>,
        <<"conn.max_retries = 15">>,
        <<"conn.reconnect_interval = 0">>,
        <<"conn.no_network_timeout = 30">>,
        <<"smp.restart_time = 21:00">>,
        <<"smp.restart_time_shift = 1440">>,
        <<"smp.bos_timeout = 0">>,
        <<"conn.at_band = 0">>,
        <<"conn.at_cops = ">>,
        <<"conn.at_wmbs = 30">>,
        <<"eventpush.sms_lost_text = Power lost">>,
        <<"eventpush.sms_return_text = Power return">>,
        <<"eventpush.addr = ">>,
        <<"eventpush.sms_notify = 3">>,
        <<"eventpush.sms_text = ">>,
        <<"rs485.mode = 4">>,
        <<"dcd.mode = 0">>,
        <<"tm.baud = 9600">>,
        <<"tm.mode8n1 = 1">>,
        <<"smp.always_on = 1">>,
        <<"smp.connect_start = FFFFFFFFFF00000">>,
        <<"smp.connect_interval = 0">>,
        <<"smp.disconnect_delay = 30">>,
        <<"led1 = 1">>,
        <<"led2 = 4">>,
        <<"led3 = 6">>,
        <<"sim.pin_code = ">>,
        <<"smp.nta_mode = 1">>,
        <<"conn.apn_auth = 0">>,
        <<"conn.pdp_by_eps = 0">>,
        <<"sim.esim = 0">>,
        <<"conn.ping_host = 0.0.0.0">>,
        <<"conn.ping_max_retries = 3">>,
        <<"conn.ping_retry_delay = 5.10.15.30.60">>,
        <<"conn.ping_interval = 60000">>,
        <<"conn.ping_timeout = 15000">>,
        <<"datapush.host = ">>,
        <<"datapush.iec_address = ">>,
        <<"datapush.interval = 86400">>,
        <<"datapush.periodic = 0">>,
        <<"dlms.lls_secret = ">>,
        <<"datapush.prefix = ">>,
        <<"datapush.table_mask = 0">>,
        <<"datapush.iec_readout_baudrate = 0">>,
        <<"datapush.max_retries = 3">>,
        <<"datapush.retry_delay = 0">>,
        <<"conn.cicb = 0">>,
        <<"conn.rings = 3">>,
        <<"pdp.delay = 3">>,
        <<"csd.password = ">>,
        <<"csd.call_accept_from = ">>,
        <<"csd.call_accept_to = ">>,
        <<"csd.protocol = 0">>,
        <<"csd.fragment = 0">>,
        <<"csd.fragment_timeout = 0">>,
        <<"calendar.dst_begin = FFFF03FE07020000003C">>,
        <<"calendar.dst_end = FFFF0AFE070300000078">>,
        <<"calendar.dst_enabled = 1">>,
        <<"calendar.dst_deviation = 60">>,
        <<"calendar.timezone = 60">>,
        <<"emeter.date_format = YYMMDD">>,
        <<"emeter.iec_address = ">>,
        <<"emeter.iec_password = 00000000">>,
        <<"ntp.address = ">>,
        <<"ntp.port = 0">>,
        <<"ntp.interval = 0">>,
        <<"ntp.timeout = 0">>,
        <<"ntp.timezone = 0">>,
        <<"snmp.trap = 0">>,
        <<"snmp.version = 0">>,
        <<"snmp.auth_algo = 0">>,
        <<"snmp.priv_algo = 0">>,
        <<"snmp.port_in = 0">>,
        <<"snmp.username = ">>,
        <<"snmp.auth_key = ">>,
        <<"snmp.priv_key = ">>,
        <<"snmp.manager_IP = ">>,
        <<"snmp.manager_port = 0">>,
        <<"fw_server.crypt = 0">>,
        <<"fw_server.key = ">>,
        <<"smp.reboot = 0">>,
        <<"dm.server = 172.31.112.225">>,
        <<"dm.port = 57609">>,
        <<"dm.push_enable = 1">>,
        <<"dm.push_interval = 60">>,
        <<"dm.tls_enable = 0">>,
        <<"dm.cert = 0">>,
        <<"dm.ca_cert = 0">>,
        <<"dm.use_crl = 0">>,
        <<"dm.verify = 0">>,
        <<"tm.tls_enable = 0">>,
        <<"tm.cert = 0">>,
        <<"tm.ca_cert = 0">>,
        <<"tm.use_crl = 0">>,
        <<"tm.verify = 0">>,
        <<"fw_server.baud = 9600">>,
        <<"syslog.category_id_filter = 105398939">>,
        <<"syslog.message_id_filter = 65535.31.0.8191.255.0.0.255.0.1.0.0.0.0.7.0.0.0.0.7.0.0.7.0.0.1.3.0.0.0.0.0">>,
        <<"user_syslog.category_id_filter = 105398939">>,
        <<"user_syslog.message_id_filter = 65535.30.0.8191.255.0.0.255.0.1.0.0.0.0.4.0.0.0.0.4.0.0.4.0.0.1.2.0.0.0.0.0">>,
        <<"user_syslog.dm_category_id_filter = 67649691">>,
        <<"user_syslog.dm_message_id_filter = 2035.7.20.0.2.193.0.0.12.0.0.0.0.0.0.2.0.0.0.0.0.0.0.0.0.0.0.10.0.0.0.0.0">>
    ],
    iolist_to_binary([lists:join(<<"\n">>, ConfigLines ++ smp_lines(IMEI)), <<"\n">>]).

%% WM-E status read (0x0D): the same modem snapshot as wmr STAT, without the
%% `STAT:' tag — plus certificate validity, RTC, UPTIME and SECSTAT.
status_blob(IMEI) ->
    Lines = smp_lines(IMEI) ++ [
        <<"emeter.ca.validity = 2026-05-19 08:38:07;2032-08-06 15:24:56">>,
        <<"config.ca.validity = 2026-05-19 08:38:07;2032-08-06 15:24:56">>,
        <<"crl.validity = 0000-00-00 00:00:00;0000-00-00 00:00:00">>,
        <<"RTC:", (rtc_utc())/binary>>,
        uptime_line(IMEI),
        secstat_line(IMEI)
    ],
    iolist_to_binary([lists:join(<<"\n">>, Lines), <<"\n">>]).

%% System syslog blob for WM-E read (0x50/0x10): RFC5424-style WM-E lines with
%% CATEGORY_DEVICE payloads (plans/Syslog.md), deterministic per IMEI.
-spec syslog_blob(binary()) -> binary().
syslog_blob(IMEI) ->
    N = 1 + erlang:phash2({IMEI, syslog}) rem 5,
    Lines = [wme_syslog:format_entry(Opts) || Opts <- syslog_entries(IMEI, N)],
    iolist_to_binary(Lines).

syslog_entries(IMEI, N) ->
    Pool = [
        #{message_id => 1, payload => <<"5.3.61.0, 1">>},
        #{message_id => 12, payload => syslog_config_start(IMEI)},
        #{message_id => 13, payload => <<>>},
        #{message_id => 10, payload => <<>>},
        #{message_id => 8, payload => syslog_overflow(IMEI)}
    ],
    [lists:nth(1 + erlang:phash2({IMEI, I}) rem length(Pool), Pool)
     || I <- lists:seq(1, N)].

syslog_config_start(IMEI) ->
    case erlang:phash2({IMEI, cfg}) rem 3 of
        0 -> <<"CONFIG">>;
        1 -> <<"LOCAL">>;
        _ -> <<"MODEM">>
    end.

syslog_overflow(IMEI) ->
    Ifaces = [<<"EMETER RX">>, <<"MODEM RX">>, <<"CONFIG RX">>, <<"CI RX">>],
    lists:nth(1 + erlang:phash2({IMEI, ovf}) rem length(Ifaces), Ifaces).

%% Shared modem identity / radio snapshot used by config and status reads.
smp_lines(IMEI) ->
    {Rssi, Sinr, Rsrq, Rsrp} = signal(IMEI),
    OsVersion = iolist_to_binary(
        io_lib:format("smp.os_version = EC200A EC200AEUHAR01A30M16 OPERATOR=21601 "
                      "NET=21601,7 STATUS=1 IP=172.31.158.137 RSSI=~b TXPWR=0 "
                      "CID=71937 SINR=~b ECIO=0 RSRQ=~b RSRP=~b",
                      [Rssi, Sinr, Rsrq, Rsrp])),
    [<<"smp.firmware_version = 5.3.61.0">>,
     OsVersion,
     <<"smp.revision_id = WM-E1S WM-E1S 3.2.6">>,
     <<"smp.modem_sn = 142588346492215954">>,
     <<"smp.modem_imei = ", IMEI/binary, ", ICC = 8936200000550566520F">>,
     <<"smp.sim_imsi = 216012055056652">>,
     <<"smp.vendor = WM Systems LLC.">>,
     <<"smp.lte_bands = 3">>,
     <<"smp.battery = 4200, CAPACITY = 100">>,
     <<"smp.engineID = 0x8000CBCE03", (engine_tail(IMEI))/binary>>].

uptime_line(IMEI) ->
    Uptime = (1 + erlang:phash2(IMEI) rem 864000) / 100.0,
    iolist_to_binary(io_lib:format("UPTIME:~.2f", [Uptime])).

secstat_line(IMEI) ->
    P = dmd_config:get(dmd_agent, secstat_probability, 1.0),
    Threshold = trunc(P * 100),
    Value = case erlang:phash2(IMEI) rem 100 < Threshold of true -> 1; false -> 0 end,
    <<"SECSTAT:", (integer_to_binary(Value))/binary>>.

rtc_utc() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:universal_time(),
    iolist_to_binary(
      io_lib:format("~4..0b-~2..0b-~2..0bT~2..0b:~2..0b:~2..0b+00:00",
                    [Y, Mo, D, H, Mi, S])).

%% Deterministic per-device signal levels within typical LTE ranges.
signal(IMEI) ->
    H = erlang:phash2(IMEI),
    {-50 - (H rem 61),            %% RSSI -50..-110
     H rem 31,                    %% SINR 0..30
     -3 - ((H bsr 4) rem 18),     %% RSRQ -3..-20
     -70 - ((H bsr 8) rem 51)}.   %% RSRP -70..-120

%% Engine-id tail: last 12 digits of the IMEI (as in real WM-E1S units).
engine_tail(IMEI) ->
    case byte_size(IMEI) of
        N when N >= 12 -> binary:part(IMEI, N - 12, 12);
        _ -> IMEI
    end.
