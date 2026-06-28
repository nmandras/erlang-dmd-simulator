%%% @doc Lightweight runtime metrics collector.
%%%
%%% One instance per runnable app (registered as `dmd_metrics_<app>'). Workers
%%% record counters ({@link incr/2}) and timing samples ({@link observe/3}) via
%%% fire-and-forget casts. When the app shuts down the supervisor terminates
%%% this process, and {@link terminate/2} renders an ASCII report — counter bar
%%% charts plus latency histograms — into that app's log file.
-module(dmd_metrics).
-behaviour(gen_server).

-export([start_link/2, incr/2, incr/3, observe/3, snapshot/1, report/1, name/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(BAR_WIDTH, 40).
-define(HIST_BUCKETS, 6).

-spec name(atom()) -> atom().
name(App) -> list_to_atom("dmd_metrics_" ++ atom_to_list(App)).

start_link(App, Domain) ->
    gen_server:start_link({local, name(App)}, ?MODULE, [App, Domain], []).

-spec incr(atom(), term()) -> ok.
incr(App, Key) -> incr(App, Key, 1).

-spec incr(atom(), term(), integer()) -> ok.
incr(App, Key, N) -> gen_server:cast(name(App), {incr, Key, N}).

%% Record a numeric sample (e.g. a latency in ms) under Key.
-spec observe(atom(), term(), number()) -> ok.
observe(App, Key, Value) -> gen_server:cast(name(App), {observe, Key, Value}).

-spec snapshot(atom()) -> map().
snapshot(App) -> gen_server:call(name(App), snapshot).

%% Render the report now (in addition to the automatic one at shutdown).
-spec report(atom()) -> ok.
report(App) -> gen_server:call(name(App), report).

%%====================================================================
%% gen_server
%%====================================================================

init([App, Domain]) ->
    process_flag(trap_exit, true),  %% ensure terminate/2 runs on shutdown
    {ok, #{app => App, domain => Domain, started => now_ms(),
           counters => #{}, samples => #{}}}.

handle_call(snapshot, _From, S) ->
    {reply, S, S};
handle_call(report, _From, S) ->
    do_report(S),
    {reply, ok, S};
handle_call(_Req, _From, S) ->
    {reply, {error, unknown_request}, S}.

handle_cast({incr, Key, N}, S = #{counters := C}) ->
    {noreply, S#{counters => maps:update_with(Key, fun(X) -> X + N end, N, C)}};
handle_cast({observe, Key, V}, S = #{samples := Sm}) ->
    {noreply, S#{samples => maps:update_with(Key, fun(L) -> [V | L] end, [V], Sm)}};
handle_cast(_Msg, S) ->
    {noreply, S}.

handle_info(_Info, S) -> {noreply, S}.

terminate(_Reason, S) ->
    do_report(S),
    ok.

%%====================================================================
%% Reporting
%%====================================================================

do_report(#{app := App, domain := Domain, started := T0,
            counters := C, samples := Sm}) ->
    Uptime = (now_ms() - T0) div 1000,
    Log = fun(Fmt, Args) -> logger:info(Fmt, Args, #{domain => Domain}) end,
    Log("==================== ~s metrics (uptime ~bs) ====================",
        [App, Uptime]),
    render_counters(C, Log),
    render_samples(Sm, Log),
    Log("==================== end ~s metrics ====================", [App]).

render_counters(C, _Log) when map_size(C) =:= 0 ->
    ok;
render_counters(C, Log) ->
    Log("counters:", []),
    Max = lists:max(maps:values(C)),
    [Log("  ~-22ts ~7b |~ts", [key_str(K), V, bar(V, Max, ?BAR_WIDTH)])
     || {K, V} <- lists:sort(maps:to_list(C))],
    ok.

render_samples(Sm, Log) ->
    maps:foreach(fun(K, L) -> render_sample(K, L, Log) end, Sm).

render_sample(Key, Samples0, Log) ->
    Samples = lists:sort(Samples0),
    N = length(Samples),
    Min = hd(Samples),
    Max = lists:last(Samples),
    Avg = lists:sum(Samples) / N,
    P95 = percentile(Samples, 0.95),
    Log("~ts: n=~b min=~w avg=~.1f max=~w p95=~w",
        [key_str(Key), N, Min, Avg, Max, P95]),
    histogram(Samples, Min, Max, Log).

histogram(Samples, Min, Max, Log) when Max > Min ->
    Span = Max - Min,
    Width = erlang:max(1, (Span + ?HIST_BUCKETS - 1) div ?HIST_BUCKETS),
    Counts = lists:foldl(
               fun(V, Acc) ->
                   Idx = erlang:min(?HIST_BUCKETS - 1, trunc((V - Min) / Width)),
                   maps:update_with(Idx, fun(X) -> X + 1 end, 1, Acc)
               end, #{}, Samples),
    CMax = lists:max([1 | maps:values(Counts)]),
    [begin
         Lo = Min + I * Width,
         Hi = Lo + Width - 1,
         Cnt = maps:get(I, Counts, 0),
         Log("  ~6w-~-6w |~ts ~b", [Lo, Hi, bar(Cnt, CMax, 30), Cnt])
     end || I <- lists:seq(0, ?HIST_BUCKETS - 1)],
    ok;
histogram(_Samples, _Min, _Max, Log) ->
    Log("  (all samples equal)", []).

%%====================================================================
%% Helpers
%%====================================================================

bar(_V, Max, _Width) when Max =< 0 -> "";
bar(V, Max, Width) -> lists:duplicate(round(V / Max * Width), $#).

percentile(Sorted, P) ->
    N = length(Sorted),
    Idx = erlang:max(1, erlang:min(N, round(P * N))),
    lists:nth(Idx, Sorted).

key_str(K) when is_atom(K) -> atom_to_list(K);
key_str(K) -> lists:flatten(io_lib:format("~p", [K])).

now_ms() -> erlang:monotonic_time(millisecond).
