%%% @doc Limits concurrent outbound TCP connections per application.
%%%
%%% Large fleets open a short-lived socket on every CALL (and the management
%%% server opens reverse connections for STAT-on-CALL). Without a cap, bursts
%%% can exhaust file descriptors or ephemeral ports and `gen_tcp:connect/4'
%%% returns `{error, system_limit}'.
-module(dmd_conn_limit).
-behaviour(gen_server).

-export([start_link/1, try_acquire/1, acquire/2, release/1, with/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(DEFAULT_MAX, 500).

start_link(App) when is_atom(App) ->
    Max = dmd_config:get(App, max_connect_inflight, ?DEFAULT_MAX),
    gen_server:start_link({local, reg_name(App)}, ?MODULE, {App, Max}, []).

-spec try_acquire(atom()) -> ok | throttled.
try_acquire(App) ->
    gen_server:call(reg_name(App), try_acquire, infinity).

-spec acquire(atom(), timeout()) -> ok | {error, timeout}.
acquire(App, Timeout) ->
    gen_server:call(reg_name(App), acquire, Timeout).

-spec release(atom()) -> ok.
release(App) ->
    gen_server:cast(reg_name(App), release).

%% Run Fun while holding one inflight slot; waits up to 30s when saturated.
-spec with(atom(), fun(() -> term())) -> term().
with(App, Fun) when is_function(Fun, 0) ->
    case try_acquire(App) of
        ok ->
            try Fun()
            after release(App) end;
        throttled ->
            case acquire(App, 30000) of
                ok ->
                    try Fun()
                    after release(App) end;
                {error, timeout} ->
                    {error, connect_throttled}
            end
    end.

init({App, Max}) ->
    logger:info("connect inflight limit ~p for ~p", [Max, App],
                #{domain => [dmd, App]}),
    {ok, #{app => App, max => Max, in_use => 0, wait => queue:new()}}.

handle_call(try_acquire, _From, #{in_use := N, max := Max} = S) when N < Max ->
    {reply, ok, S#{in_use => N + 1}};
handle_call(try_acquire, _From, S) ->
    {reply, throttled, S};

handle_call(acquire, _From, #{in_use := N, max := Max} = S) when N < Max ->
    {reply, ok, S#{in_use => N + 1}};
handle_call(acquire, From, S) ->
    {noreply, S#{wait => queue:in(From, maps:get(wait, S))}}.

handle_cast(release, S) ->
    {noreply, grant_waiter(S)}.

handle_info({'DOWN', _Ref, process, Pid, _}, S) ->
    {noreply, drop_waiter(Pid, S)};
handle_info(_Info, S) ->
    {noreply, S}.

grant_waiter(#{in_use := 0} = S) ->
    S;
grant_waiter(#{in_use := N, wait := Q} = S) ->
    case queue:out(Q) of
        {empty, _} ->
            S#{in_use => N - 1};
        {{value, From}, Q2} ->
            monitor_caller(From),
            gen_server:reply(From, ok),
            S#{wait => Q2}
    end.

drop_waiter(Pid, #{wait := Q} = S) ->
    S#{wait => queue:filter(fun(From) -> caller_pid(From) =/= Pid end, Q)}.

monitor_caller(From) when is_pid(From) ->
    ok;
monitor_caller(From) ->
    case caller_pid(From) of
        Pid when is_pid(Pid) -> erlang:monitor(process, Pid);
        _ -> ok
    end.

caller_pid(From) ->
    element(1, From).

reg_name(dmd_agent) -> dmd_conn_limit_agent;
reg_name(dmd_mgmt) -> dmd_conn_limit_mgmt;
reg_name(App) -> list_to_atom("dmd_conn_limit_" ++ atom_to_list(App)).
