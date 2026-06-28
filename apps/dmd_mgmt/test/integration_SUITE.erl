%%% @doc End-to-end test of the two applications over plain TCP: CSV import,
%%% periodic CALLs (logged), explicit commands, and the autonomous driver.
-module(integration_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([calls_logged/1, command_works/1, driver_runs/1, unknown_device/1]).

-define(MGMT_PORT, 5055).

all() ->
    [calls_logged, command_works, driver_runs, unknown_device].

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
                    {reboot_duration_ms, 1000}, {log_file, AgentLog}, {tls, false}]),
    set(dmd_mgmt, [{csv_file, Csv}, {mgmt_host, {127,0,0,1}}, {mgmt_port, ?MGMT_PORT},
                   {log_file, MgmtLog}, {driver_enabled, true},
                   {driver_min_ms, 300}, {driver_max_ms, 800}, {tls, false}]),

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
    ?assert(file_contains(?config(agent_log, Config), <<"CALL imei=">>)),
    ?assert(file_contains(?config(mgmt_log, Config), <<"CALL recv imei=">>)),
    ok.

%% Explicit STAT round-trips with a success code and status payload.
command_works(_Config) ->
    IMEI = <<"101000000000001">>,
    {ok, {<<"STAT">>, 0, Data}} = dmd_mgmt:send_command(IMEI, stat),
    ?assert(byte_size(Data) > 0),
    ok.

%% The autonomous driver issues commands and they are traceable in the log.
driver_runs(Config) ->
    ok = wait_until(fun() -> dmd_mgmt:driver_count() > 0 end, 100),
    ?assert(file_contains(?config(mgmt_log, Config), <<"DRIVER cmd=">>)),
    ok.

unknown_device(_Config) ->
    ?assertEqual({error, device_not_found},
                 dmd_mgmt:send_command(<<"999999999999999">>, stat)),
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

wait_until(_Fun, 0) -> {error, timeout};
wait_until(Fun, N) ->
    case Fun() of
        true -> ok;
        false -> timer:sleep(200), wait_until(Fun, N - 1)
    end.
