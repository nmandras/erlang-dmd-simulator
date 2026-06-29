%%% @doc End-to-end test of the two applications over plain TCP: CSV import,
%%% periodic CALLs (logged), explicit commands, and the autonomous driver.
-module(integration_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([calls_logged/1, command_works/1, reboot_command/1, driver_runs/1,
         unknown_device/1, metrics_collected/1, call_triggers_stat/1,
         seclog_command/1, stat_triggers_seclog/1, wme_config_read/1]).

-define(MGMT_PORT, 5055).

all() ->
    [calls_logged, command_works, reboot_command, seclog_command,
     wme_config_read, call_triggers_stat, stat_triggers_seclog,
     driver_runs, unknown_device, metrics_collected].

init_per_suite(Config) ->
    Priv = ?config(priv_dir, Config),
    Csv = filename:join(Priv, "devices.csv"),
    %% 3 devices on 127.0.0.31..33:6060, 1-second call period.
    ok = dmd_csv:write(Csv, dmd_csv:generate(3, 101000000000001, 31, 6060, 1)),
    AgentLog = filename:join(Priv, "agent.log"),
    MgmtLog = filename:join(Priv, "mgmt.log"),

    application:load(dmd_agent),
    application:load(dmd_mgmt),

    set(dmd_agent, [{csv_file, Csv}, {mgmt_host, {127,0,0,1}}, {mgmt_port, ?MGMT_PORT},
                    {reboot_duration_ms, 1000},
                    {log_file, AgentLog}, {tls, false}]),
    %% Driver disabled so device state stays deterministic for the explicit
    %% command tests; driver_runs exercises it on demand via driver_trigger.
    set(dmd_mgmt, [{csv_file, Csv}, {mgmt_host, {127,0,0,1}}, {mgmt_port, ?MGMT_PORT},
                   {log_file, MgmtLog}, {driver_enabled, false}, {tls, false}]),

    {ok, _} = application:ensure_all_started(dmd_mgmt),
    {ok, _} = application:ensure_all_started(dmd_agent),
    [{csv, Csv}, {agent_log, AgentLog}, {mgmt_log, MgmtLog} | Config].

end_per_suite(_Config) ->
    application:stop(dmd_agent),
    application:stop(dmd_mgmt),
    ok.

%% Devices CALL in and are recorded; both log files show timestamped CALLs.
calls_logged(Config) ->
    ok = wait_until(fun() ->
        Ds = dmd_mgmt:list_devices(),
        length(Ds) >= 3 andalso
            lists:all(fun(M) -> maps:get(calls, M, 0) > 0 end, Ds)
    end, 100),
    ok = wait_file(?config(agent_log, Config), <<"CALL imei=">>),
    ok = wait_file(?config(mgmt_log, Config), <<"CALL recv imei=">>),
    ok.

%% Explicit STAT round-trips with a success code and status payload.
command_works(_Config) ->
    IMEI = <<"101000000000001">>,
    {ok, {<<"STAT">>, 0, Data}} = dmd_mgmt:send_command(IMEI, stat),
    ?assert(byte_size(Data) > 0),
    ok.

%% REBOOT acks (code 0); STAT fails (code 1) while rebooting, then recovers.
reboot_command(_Config) ->
    IMEI = <<"101000000000003">>,
    {ok, {<<"REBOOT">>, 0, _}} = dmd_mgmt:send_command(IMEI, reboot),
    {ok, {<<"STAT">>, 1, _}} = dmd_mgmt:send_command(IMEI, stat),
    ok = wait_until(fun() ->
        case dmd_mgmt:send_command(IMEI, stat) of
            {ok, {<<"STAT">>, 0, _}} -> true;
            _ -> false
        end
    end, 100),
    ok.

%% The driver issues commands on demand and they are traceable in the log.
driver_runs(Config) ->
    [dmd_mgmt:driver_trigger() || _ <- lists:seq(1, 3)],
    ok = wait_until(fun() -> dmd_mgmt:driver_count() > 0 end, 100),
    ok = wait_file(?config(mgmt_log, Config), <<"DRIVER cmd=">>),
    ok.

unknown_device(_Config) ->
    ?assertEqual({error, device_not_found},
                 dmd_mgmt:send_command(<<"999999999999999">>, stat)),
    ok.

%% The server acts as a WMETerm client and reads the device's WM-E config blob
%% over the device's WM-E port; it matches what the device serves.
wme_config_read(_Config) ->
    IMEI = <<"101000000000001">>,
    {ok, Blob} = dmd_mgmt:wme_read_config(IMEI, config),
    {ok, Expected} = device_wme:config_blob(IMEI, 16#FF),
    ?assertEqual(Expected, Blob),
    ?assert(byte_size(Blob) > 256),  %% spans multiple V1 packets
    ok.

%% SECLOG returns 1..5 syslog-format security event lines.
seclog_command(_Config) ->
    IMEI = <<"101000000000001">>,
    {ok, {<<"SECLOG">>, 0, Body}} = dmd_mgmt:send_command(IMEI, seclog),
    ?assert(byte_size(Body) > 0),
    Lines = binary:split(Body, <<"\n">>, [global]),
    ?assert(length(Lines) >= 1 andalso length(Lines) =< 5),
    ok.

%% A STAT carrying SECSTAT:1 makes the server follow up with a SECLOG; the
%% on-CALL STAT path exercises this, so the seclog_triggered metric rises and
%% both logs show the seclog command.
stat_triggers_seclog(Config) ->
    ok = wait_until(fun() ->
        #{counters := C} = dmd_metrics:snapshot(dmd_mgmt),
        maps:get(seclog_triggered, C, 0) > 0
    end, 100),
    ok = wait_file(?config(mgmt_log, Config), <<"cmd=seclog">>),
    ok = wait_file(?config(agent_log, Config), <<"cmd=seclog">>),
    ok.

%% Each received CALL makes the server poll the caller with a STAT, which the
%% device records as a received command.
call_triggers_stat(_Config) ->
    ok = wait_until(fun() ->
        #{counters := C} = dmd_metrics:snapshot(dmd_mgmt),
        maps:get(call_triggered_stat, C, 0) > 0
    end, 100),
    ok = wait_until(fun() ->
        #{counters := C} = dmd_metrics:snapshot(dmd_agent),
        maps:get(commands_received, C, 0) > 0
    end, 100),
    ok.

%% Both apps collect counters/samples and can render a report on demand.
metrics_collected(_Config) ->
    #{counters := MgmtC} = dmd_metrics:snapshot(dmd_mgmt),
    ?assert(maps:get(calls_received, MgmtC, 0) > 0),
    #{counters := AgentC} = dmd_metrics:snapshot(dmd_agent),
    ?assert(maps:get(calls_sent_ok, AgentC, 0) > 0),
    ?assertEqual(ok, dmd_metrics:report(dmd_mgmt)),
    ?assertEqual(ok, dmd_metrics:report(dmd_agent)),
    ok.

%%====================================================================
%% Helpers
%%====================================================================

set(App, KVs) ->
    [application:set_env(App, K, V) || {K, V} <- KVs],
    ok.

file_contains(Path, Needle) ->
    case file:read_file(Path) of
        {ok, Bin} -> binary:match(Bin, Needle) =/= nomatch;
        _ -> false
    end.

%% Poll for a log line; the logger file handler flushes asynchronously.
wait_file(Path, Needle) ->
    wait_until(fun() -> file_contains(Path, Needle) end, 100).

wait_until(_Fun, 0) -> {error, timeout};
wait_until(Fun, N) ->
    case Fun() of
        true -> ok;
        false -> timer:sleep(200), wait_until(Fun, N - 1)
    end.
