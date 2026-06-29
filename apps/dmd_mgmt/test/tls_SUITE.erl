%%% @doc End-to-end test with TLS enabled across both applications. Generates a
%%% self-signed cert in the suite's private dir; skipped if openssl is missing.
-module(tls_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([tls_call_and_command/1]).

-define(MGMT_PORT, 5066).

all() ->
    [tls_call_and_command].

init_per_suite(Config) ->
    case os:find_executable("openssl") of
        false ->
            {skip, "openssl not available"};
        _ ->
            Priv = ?config(priv_dir, Config),
            Cert = filename:join(Priv, "server.pem"),
            Key = filename:join(Priv, "server.key"),
            Cmd = lists:flatten(io_lib:format(
                "openssl req -x509 -newkey rsa:2048 -nodes -keyout ~s "
                "-out ~s -days 1 -subj /CN=localhost 2>&1", [Key, Cert])),
            _ = os:cmd(Cmd),
            case filelib:is_file(Cert) andalso filelib:is_file(Key) of
                false ->
                    {skip, "could not generate certificate"};
                true ->
                    start_apps(Config, Priv, Cert, Key)
            end
    end.

start_apps(Config, Priv, Cert, Key) ->
    Csv = filename:join(Priv, "devices.csv"),
    ok = dmd_csv:write(Csv, dmd_csv:generate(2, 0, #{start_imei => 101000000000001,
                                                     base_ip => {127,10,0,41},
                                                     mgmt_port => 6070,
                                                     period_sec => 1})),
    Tls = [{listen,  [{certfile, Cert}, {keyfile, Key}]},
           {connect, [{verify, verify_none}]}],
    application:load(dmd_agent),
    application:load(dmd_mgmt),
    set(dmd_agent, [{csv_file, Csv}, {mgmt_host, {127,0,0,1}}, {mgmt_port, ?MGMT_PORT},
                    {log_file, filename:join(Priv, "agent.log")},
                    {tls, true}, {tls_opts, Tls}]),
    set(dmd_mgmt, [{csv_file, Csv}, {mgmt_host, {127,0,0,1}}, {mgmt_port, ?MGMT_PORT},
                   {log_file, filename:join(Priv, "mgmt.log")},
                   {driver_enabled, false}, {tls, true}, {tls_opts, Tls}]),
    {ok, _} = application:ensure_all_started(dmd_mgmt),
    {ok, _} = application:ensure_all_started(dmd_agent),
    [{started, true} | Config].

end_per_suite(Config) ->
    case ?config(started, Config) of
        true ->
            application:stop(dmd_agent),
            application:stop(dmd_mgmt);
        _ -> ok
    end,
    ok.

tls_call_and_command(_Config) ->
    IMEI = <<"101000000000001">>,
    %% CALLs arrive over TLS and populate the registry.
    ok = wait_until(fun() ->
        case lists:filter(fun(M) -> maps:get(imei, M) =:= IMEI end,
                          dmd_mgmt:list_devices()) of
            [M] -> maps:get(calls, M, 0) > 0;
            _ -> false
        end
    end, 100),
    %% Commands round-trip over TLS too.
    {ok, {<<"STAT">>, 0, Data}} = dmd_mgmt:send_command(IMEI, stat),
    ?assert(byte_size(Data) > 0),
    ok.

set(App, KVs) ->
    [application:set_env(App, K, V) || {K, V} <- KVs],
    ok.

wait_until(_Fun, 0) -> {error, timeout};
wait_until(Fun, N) ->
    case Fun() of
        true -> ok;
        false -> timer:sleep(200), wait_until(Fun, N - 1)
    end.
