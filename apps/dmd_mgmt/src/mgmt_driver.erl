%%% @doc Autonomous command driver.
%%%
%%% At random intervals the management server picks a random known device and
%%% issues a random command (mostly STAT, occasionally REBOOT), then logs the
%%% command and its result — so server-initiated activity is fully traceable
%%% from the management log file.
-module(mgmt_driver).
-behaviour(gen_server).

-export([start_link/0, count/0, trigger/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(DOMAIN, #{domain => [dmd, mgmt]}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Number of commands issued so far (useful for tests/inspection).
-spec count() -> non_neg_integer().
count() -> gen_server:call(?MODULE, count).

%% Fire one command immediately (in addition to the scheduled ones).
-spec trigger() -> ok.
trigger() -> gen_server:cast(?MODULE, tick).

init([]) ->
    State = #{count => 0},
    case dmd_config:get(dmd_mgmt, driver_enabled, true) of
        true -> {ok, schedule(State)};
        false -> {ok, State}
    end.

handle_call(count, _From, S) ->
    {reply, maps:get(count, S, 0), S};
handle_call(_Req, _From, S) ->
    {reply, {error, unknown_request}, S}.

handle_cast(tick, S) ->
    {noreply, do_tick(S)};
handle_cast(_Msg, S) ->
    {noreply, S}.

handle_info(tick, S) ->
    {noreply, schedule(do_tick(S))};
handle_info(_Info, S) ->
    {noreply, S}.

terminate(_Reason, _S) -> ok.

%%====================================================================
%% Internal
%%====================================================================

schedule(S) ->
    Min = dmd_config:get(dmd_mgmt, driver_min_ms, 3000),
    Max = dmd_config:get(dmd_mgmt, driver_max_ms, 8000),
    Delay = Min + rand:uniform(max(1, Max - Min)),
    erlang:send_after(Delay, self(), tick),
    S.

do_tick(S) ->
    %% Only wmr devices accept text STAT/REBOOT commands.
    case [D || D <- mgmt_registry:all(), maps:get(device_type, D, 1) =:= 1] of
        [] ->
            S;
        Devices ->
            Device = lists:nth(rand:uniform(length(Devices)), Devices),
            IMEI = maps:get(imei, Device),
            Cmd = random_command(),
            T0 = erlang:monotonic_time(millisecond),
            Result = mgmt_commander:send_command(IMEI, Cmd),
            Dt = erlang:monotonic_time(millisecond) - T0,
            record(Cmd, Result, Dt),
            logger:info("DRIVER cmd=~s imei=~s result=~p",
                        [Cmd, IMEI, summarise(Result)], ?DOMAIN),
            S#{count => maps:get(count, S, 0) + 1}
    end.

%% Weighted: reboot ~1 in 4, otherwise stat.
random_command() ->
    case rand:uniform(4) of
        1 -> reboot;
        _ -> stat
    end.

summarise({ok, {Name, Code, _Data}}) -> {Name, Code};
summarise(Other) -> Other.

record(Cmd, Result, Dt) ->
    dmd_metrics:incr(dmd_mgmt, driver_total),
    dmd_metrics:incr(dmd_mgmt, cmd_key(Cmd)),
    case Result of
        {ok, {_Name, 0, _Data}} ->
            dmd_metrics:incr(dmd_mgmt, driver_ok),
            dmd_metrics:observe(dmd_mgmt, cmd_latency_ms, Dt);
        _ ->
            dmd_metrics:incr(dmd_mgmt, driver_failed)
    end.

cmd_key(stat) -> driver_stat;
cmd_key(reboot) -> driver_reboot.
