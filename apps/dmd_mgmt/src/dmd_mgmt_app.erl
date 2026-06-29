%%% @doc Management server application: installs the server log handler, starts
%%% the supervision tree, then loads the device inventory CSV into the registry.
-module(dmd_mgmt_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) ->
    LogFile = dmd_config:get(dmd_mgmt, log_file, "log/mgmt.log"),
    ok = dmd_log:setup(dmd_mgmt_log, LogFile, [dmd, mgmt]),
    {ok, Pid} = dmd_mgmt_sup:start_link(),
    maybe_load_csv(),
    {ok, Pid}.

stop(_State) ->
    ok.

maybe_load_csv() ->
    case dmd_config:get(dmd_mgmt, csv_file, undefined) of
        undefined ->
            ok;
        Path ->
            case dmd_csv:read(Path) of
                {ok, Rows} ->
                    [mgmt_registry:register(maps:get(imei, Row), Row#{status => provisioned})
                     || Row <- Rows],
                    logger:info("inventory loaded from ~s: ~b device(s)",
                                [Path, length(Rows)], #{domain => [dmd, mgmt]});
                {error, Reason} ->
                    logger:warning("could not load ~s: ~p",
                                   [Path, Reason], #{domain => [dmd, mgmt]})
            end
    end.
