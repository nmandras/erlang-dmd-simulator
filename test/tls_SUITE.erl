%%% @doc End-to-end test with TLS enabled. Generates a self-signed cert in the
%%% suite's private dir, runs the whole CALL + command flow over ssl, and is
%%% skipped if openssl is unavailable.
-module(tls_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([tls_call_and_command/1]).

all() ->
    [tls_call_and_command].

init_per_suite(Config) ->
    case os:find_executable("openssl") of
        false ->
            {skip, "openssl not available"};
        _ ->
            Dir = ?config(priv_dir, Config),
            Cert = filename:join(Dir, "server.pem"),
            Key = filename:join(Dir, "server.key"),
            Cmd = lists:flatten(io_lib:format(
                "openssl req -x509 -newkey rsa:2048 -nodes -keyout ~s "
                "-out ~s -days 1 -subj /CN=localhost 2>&1",
                [Key, Cert])),
            _ = os:cmd(Cmd),
            case filelib:is_file(Cert) andalso filelib:is_file(Key) of
                false ->
                    {skip, "could not generate certificate"};
                true ->
                    application:load(dmd),
                    application:set_env(dmd, call_interval_ms, 1000),
                    application:set_env(dmd, reboot_duration_ms, 1500),
                    application:set_env(dmd, tls, true),
                    application:set_env(dmd, tls_opts,
                        [{listen,  [{certfile, Cert}, {keyfile, Key}]},
                         {connect, [{verify, verify_none}]}]),
                    {ok, _} = application:ensure_all_started(dmd),
                    [{imeis, dmd:start_fleet(2)} | Config]
            end
    end.

end_per_suite(Config) ->
    case ?config(imeis, Config) of
        undefined -> ok;
        _ -> application:stop(dmd)
    end,
    ok.

tls_call_and_command(Config) ->
    [IMEI | _] = ?config(imeis, Config),
    %% CALLs arrive over TLS and populate the registry.
    ok = wait_until(fun() ->
        case [M || M <- dmd:list_devices(), maps:get(imei, M) =:= IMEI] of
            [M] -> maps:get(calls, M, 0) > 0;
            _ -> false
        end
    end, 50),
    %% Commands round-trip over TLS too.
    {ok, {<<"STAT">>, 0, Data}} = dmd:send_command(IMEI, stat),
    ?assert(byte_size(Data) > 0),
    ok.

wait_until(_Fun, 0) -> {error, timeout};
wait_until(Fun, N) ->
    case Fun() of
        true -> ok;
        false -> timer:sleep(200), wait_until(Fun, N - 1)
    end.
