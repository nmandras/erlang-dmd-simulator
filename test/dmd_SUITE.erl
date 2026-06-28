%%% @doc Integration tests over plain TCP: fleet registration via CALLs and
%%% server-initiated STAT/REBOOT commands.
-module(dmd_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([fleet_registers/1, stat_command/1, reboot_cycle/1, unknown_device/1]).

all() ->
    [fleet_registers, stat_command, reboot_cycle, unknown_device].

init_per_suite(Config) ->
    application:load(dmd),
    %% Speed the simulation up for tests.
    application:set_env(dmd, call_interval_ms, 1000),
    application:set_env(dmd, reboot_duration_ms, 1500),
    application:set_env(dmd, tls, false),
    {ok, _} = application:ensure_all_started(dmd),
    IMEIs = dmd:start_fleet(3),
    [{imeis, IMEIs} | Config].

end_per_suite(_Config) ->
    application:stop(dmd),
    ok.

%% Every device should appear in the registry and record at least one CALL.
fleet_registers(Config) ->
    IMEIs = ?config(imeis, Config),
    ?assertEqual(3, length(IMEIs)),
    ok = wait_until(fun() ->
        Ds = dmd:list_devices(),
        length(Ds) >= 3 andalso
            lists:all(fun(M) -> maps:get(calls, M, 0) > 0 end, Ds)
    end, 50),
    ok.

%% STAT returns success (code 0) and a non-empty status payload.
stat_command(Config) ->
    [IMEI | _] = ?config(imeis, Config),
    {ok, {<<"STAT">>, 0, Data}} = dmd:send_command(IMEI, stat),
    ?assert(byte_size(Data) > 0),
    ok.

%% REBOOT acks with code 0; STAT fails (code 1) during the reboot window,
%% then succeeds again once the device comes back.
reboot_cycle(Config) ->
    [_, IMEI | _] = ?config(imeis, Config),
    {ok, {<<"REBOOT">>, 0, _}} = dmd:send_command(IMEI, reboot),
    {ok, {<<"STAT">>, 1, _}} = dmd:send_command(IMEI, stat),
    ok = wait_until(fun() ->
        case dmd:send_command(IMEI, stat) of
            {ok, {<<"STAT">>, 0, _}} -> true;
            _ -> false
        end
    end, 50),
    ok.

%% Commanding an unknown IMEI is reported, not crashed.
unknown_device(_Config) ->
    ?assertEqual({error, device_not_found},
                 dmd:send_command(<<"999999999999999">>, stat)),
    ok.

%% Poll Fun up to N times, 200ms apart, until it returns true.
wait_until(_Fun, 0) -> {error, timeout};
wait_until(Fun, N) ->
    case Fun() of
        true -> ok;
        false -> timer:sleep(200), wait_until(Fun, N - 1)
    end.
