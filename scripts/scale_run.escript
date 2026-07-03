#!/usr/bin/env escript
%%! -pa _build/default/lib/dmd_common/ebin -pa _build/default/lib/wme/ebin -pa _build/default/lib/dmd_agent/ebin -pa _build/default/lib/dmd_mgmt/ebin +Q 1048576 +P 2000000
%%
%% Scale runner: start a mixed fleet (Wmr wmr-devices + Wme wme-devices) plus
%% the management server, generate per-type load for a while, then report.
%%
%% Usage: scripts/scale_run.escript Wmr Wme [DurationSec] [PeriodSec]
%% Defaults: 8000 wmr, 2000 wme, 40s run, 10s call period.
%%
%% wmr devices: periodic CALLs + on-CALL STAT/SECLOG + autonomous driver.
%% wme devices: a concurrent WM-E config-read benchmark (reads/s, bytes/s, ms).
%%
%% Needs a high open-file limit (one listen socket per device); run inside the
%% Docker container via scripts/docker_scale.sh, or raise ulimit -n first.

main(Args) ->
    logger:set_primary_config(level, info),
    {Wmr, Wme, Dur, Period} = parse(Args),
    ok = filelib:ensure_dir("log/"),
    Csv = "log/devices_scale.csv",
    Rows = dmd_csv:generate_scale(Wmr, Wme, Period),
    ok = dmd_csv:write(Csv, Rows),

    Total = Wmr + Wme,
    Inflight = min(2000, max(500, Total div 20)),
    setup(dmd_agent, [{csv_file, Csv}, {mgmt_host, {127,0,0,1}}, {mgmt_port, 5000},
                      {reboot_duration_ms, 5000}, {log_file, "log/agent_scale.log"},
                      {max_connect_inflight, Inflight}, {tls, false}]),
    setup(dmd_mgmt, [{csv_file, Csv}, {mgmt_host, {127,0,0,1}}, {mgmt_port, 5000},
                     {log_file, "log/mgmt_scale.log"}, {stat_on_call, true},
                     {max_connect_inflight, Inflight},
                     {driver_enabled, true}, {driver_min_ms, 1000}, {driver_max_ms, 3000},
                     {tls, false}]),

    {ok, _} = application:ensure_all_started(dmd_mgmt),
    {ok, _} = application:ensure_all_started(dmd_agent),
    io:format("started ~p wmr + ~p wme devices (period ~ps, inflight ~p); running ~ps...~n",
              [Wmr, Wme, Period, Inflight, Dur]),

    WmeImeis = [maps:get(imei, R) || R <- Rows, maps:get(device_type, R) =:= 2],
    Bench = bench_wme(WmeImeis, Dur),

    Registered = length(dmd_mgmt:list_devices()),
    #{counters := MgmtC} = dmd_metrics:snapshot(dmd_mgmt),
    #{counters := AgentC} = dmd_metrics:snapshot(dmd_agent),
    io:format("~n==== scale result ====~n"
              "devices_registered = ~p / ~p~n"
              "wmr mgmt counters  = ~p~n"
              "wmr agent counters = ~p~n"
              "wme read bench     = ~p~n",
              [Registered, Wmr + Wme, lists:sort(maps:to_list(MgmtC)),
               lists:sort(maps:to_list(AgentC)), Bench]),

    application:stop(dmd_agent),
    application:stop(dmd_mgmt),
    timer:sleep(2000),
    io:format("done; see log/agent_scale.log and log/mgmt_scale.log~n").

%%====================================================================
%% WM-E read benchmark
%%====================================================================

bench_wme([], DurSec) ->
    timer:sleep(DurSec * 1000),
    #{reads => 0};
bench_wme(Imeis, DurSec) ->
    Concurrency = min(50, length(Imeis)),
    Deadline = erlang:monotonic_time(millisecond) + DurSec * 1000,
    Parent = self(),
    Workers = [spawn_link(fun() -> worker(Imeis, Deadline, Parent, 0, 0, 0) end)
               || _ <- lists:seq(1, Concurrency)],
    {Reads, Bytes, LatSum} = collect(length(Workers), 0, 0, 0),
    AvgMs = case Reads of 0 -> 0.0; _ -> LatSum / Reads end,
    #{reads => Reads,
      reads_per_s => Reads div max(1, DurSec),
      mbytes_per_s => round(Bytes / max(1, DurSec) / 1048576 * 100) / 100,
      avg_latency_ms => round(AvgMs * 100) / 100,
      concurrency => Concurrency}.

worker(Imeis, Deadline, Parent, Reads, Bytes, LatSum) ->
    case erlang:monotonic_time(millisecond) >= Deadline of
        true ->
            Parent ! {done, Reads, Bytes, LatSum};
        false ->
            IMEI = lists:nth(rand:uniform(length(Imeis)), Imeis),
            T0 = erlang:monotonic_time(millisecond),
            case dmd_mgmt:wme_read_config(IMEI, config) of
                {ok, Blob} ->
                    Dt = erlang:monotonic_time(millisecond) - T0,
                    worker(Imeis, Deadline, Parent,
                           Reads + 1, Bytes + byte_size(Blob), LatSum + Dt);
                _Err ->
                    worker(Imeis, Deadline, Parent, Reads, Bytes, LatSum)
            end
    end.

collect(0, Reads, Bytes, LatSum) ->
    {Reads, Bytes, LatSum};
collect(N, Reads, Bytes, LatSum) ->
    receive
        {done, R, B, L} -> collect(N - 1, Reads + R, Bytes + B, LatSum + L)
    end.

%%====================================================================
%% Helpers
%%====================================================================

setup(App, KVs) ->
    application:load(App),
    [application:set_env(App, K, V) || {K, V} <- KVs],
    ok.

parse([]) -> {8000, 2000, 40, 10};
parse([W]) -> {i(W), 2000, 40, 10};
parse([W, M]) -> {i(W), i(M), 40, 10};
parse([W, M, D]) -> {i(W), i(M), i(D), 10};
parse([W, M, D, P | _]) -> {i(W), i(M), i(D), i(P)}.

i(S) -> list_to_integer(S).
