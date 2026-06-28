%%% @doc Agent application: installs the agent log handler, starts the
%%% supervision tree, and (if a CSV is configured) boots the fleet from it.
-module(dmd_agent_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) ->
    LogFile = dmd_config:get(dmd_agent, log_file, "log/agent.log"),
    ok = dmd_log:setup(dmd_agent_log, LogFile, [dmd, agent]),
    {ok, Pid} = dmd_agent_sup:start_link(),
    maybe_start_fleet(),
    {ok, Pid}.

stop(_State) ->
    ok.

maybe_start_fleet() ->
    case dmd_config:get(dmd_agent, csv_file, undefined) of
        undefined ->
            ok;
        Path ->
            case dmd_agent:start_from_csv(Path) of
                {ok, Started} ->
                    logger:info("fleet started from ~s: ~b device(s)",
                                [Path, length(Started)], #{domain => [dmd, agent]});
                {error, Reason} ->
                    logger:warning("could not load ~s: ~p",
                                   [Path, Reason], #{domain => [dmd, agent]})
            end
    end.
