#!/usr/bin/env escript
%%! -pa _build/default/lib/dmd_common/ebin -pa _build/default/lib/wme/ebin -pa _build/default/lib/dmd_agent/ebin -pa _build/default/lib/dmd_mgmt/ebin +Q 1048576 +P 2000000
%%
%% Scale runner: start a large fleet plus the management server, run for a
%% while, then stop both (which flushes each app's metrics report to its log).
%%
%% Usage: scripts/scale_run.escript [Count] [DurationSec] [PeriodSec]
%% Defaults: 10000 devices, 40s run, 10s call period.
%%
%% Needs a high open-file limit (one listen socket per device); run inside the
%% Docker container via scripts/docker_scale.sh, or raise ulimit -n first.

main(Args) ->
    %% escript does not read sys.config, so raise the primary level (default
    %% is 'notice') to let the apps' info logs through to the file handlers.
    logger:set_primary_config(level, info),
    {Count, Dur, Period} = parse(Args),
    ok = filelib:ensure_dir("log/"),
    Csv = "log/devices_scale.csv",
    ok = dmd_csv:write(Csv, dmd_csv:generate_scale(Count, 101000000000001, 6000, Period)),

    setup(dmd_agent, [{csv_file, Csv}, {mgmt_host, {127,0,0,1}}, {mgmt_port, 5000},
                      {reboot_duration_ms, 5000}, {log_file, "log/agent_scale.log"},
                      %% Keep one listen socket per device at scale (WM-E adds a
                      %% second port per device); enable it for smaller runs.
                      {wme_enabled, false}, {tls, false}]),
    setup(dmd_mgmt, [{csv_file, Csv}, {mgmt_host, {127,0,0,1}}, {mgmt_port, 5000},
                     {log_file, "log/mgmt_scale.log"}, {stat_on_call, true},
                     {driver_enabled, true}, {driver_min_ms, 1000}, {driver_max_ms, 3000},
                     {tls, false}]),

    {ok, _} = application:ensure_all_started(dmd_mgmt),
    {ok, _} = application:ensure_all_started(dmd_agent),
    io:format("started ~p devices (period ~ps); running for ~ps...~n",
              [Count, Period, Dur]),

    timer:sleep(Dur * 1000),

    Registered = length(dmd_mgmt:list_devices()),
    #{counters := MgmtC} = dmd_metrics:snapshot(dmd_mgmt),
    #{counters := AgentC} = dmd_metrics:snapshot(dmd_agent),
    io:format("~n==== scale result ====~n"
              "devices_registered = ~p / ~p~n"
              "mgmt counters      = ~p~n"
              "agent counters     = ~p~n",
              [Registered, Count, lists:sort(maps:to_list(MgmtC)),
               lists:sort(maps:to_list(AgentC))]),

    %% Stopping the apps triggers each metrics collector to render its report
    %% (bar charts + latency histograms) into the scale log files.
    application:stop(dmd_agent),
    application:stop(dmd_mgmt),
    timer:sleep(2000),
    io:format("done; see log/agent_scale.log and log/mgmt_scale.log~n").

setup(App, KVs) ->
    application:load(App),
    [application:set_env(App, K, V) || {K, V} <- KVs],
    ok.

parse([]) -> {10000, 40, 10};
parse([C]) -> {i(C), 40, 10};
parse([C, D]) -> {i(C), i(D), 10};
parse([C, D, P | _]) -> {i(C), i(D), i(P)}.

i(S) -> list_to_integer(S).
