%%% @doc Registry of known devices, backed by an ETS table owned by this
%%% gen_server. Devices self-register on start (so commands can be routed
%%% before the first CALL), and each received CALL refreshes liveness.
-module(mgmt_registry).
-behaviour(gen_server).

-export([start_link/0, register/4, touch/3, unregister/1, lookup/1, all/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TAB, dmd_registry).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Called by a device on startup with its real connect address.
-spec register(binary(), inet:ip_address(), inet:port_number(), atom()) -> ok.
register(IMEI, IP, Port, Status) ->
    gen_server:call(?MODULE, {register, IMEI, IP, Port, Status}).

%% Called by the management listener when a CALL arrives.
-spec touch(binary(), binary(), atom()) -> ok.
touch(IMEI, ReportedIP, Status) ->
    gen_server:cast(?MODULE, {touch, IMEI, ReportedIP, Status}).

-spec unregister(binary()) -> ok.
unregister(IMEI) ->
    gen_server:call(?MODULE, {unregister, IMEI}).

%% Reads go straight to ETS (the table is protected, read-optimised).
-spec lookup(binary()) -> {ok, map()} | {error, not_found}.
lookup(IMEI) ->
    case ets:lookup(?TAB, IMEI) of
        [{_, Map}] -> {ok, Map};
        [] -> {error, not_found}
    end.

-spec all() -> [map()].
all() -> [Map || {_, Map} <- ets:tab2list(?TAB)].

init([]) ->
    ?TAB = ets:new(?TAB, [named_table, set, protected, {read_concurrency, true}]),
    {ok, #{}}.

handle_call({register, IMEI, IP, Port, Status}, _From, S) ->
    Existing = case ets:lookup(?TAB, IMEI) of
                   [{_, M}] -> M;
                   [] -> #{calls => 0}
               end,
    Map = Existing#{imei => IMEI, ip => IP, port => Port, status => Status,
                    last_seen => now_s()},
    ets:insert(?TAB, {IMEI, Map}),
    {reply, ok, S};
handle_call({unregister, IMEI}, _From, S) ->
    ets:delete(?TAB, IMEI),
    {reply, ok, S};
handle_call(_Req, _From, S) ->
    {reply, {error, unknown_request}, S}.

handle_cast({touch, IMEI, ReportedIP, Status}, S) ->
    case ets:lookup(?TAB, IMEI) of
        [{_, Map}] ->
            Map1 = Map#{reported_ip => ReportedIP, status => Status,
                        last_seen => now_s(),
                        calls => maps:get(calls, Map, 0) + 1},
            ets:insert(?TAB, {IMEI, Map1});
        [] ->
            %% A device we didn't create; derive a connect address from the
            %% reported IP and the shared device port.
            IP = parse_ip(ReportedIP),
            Map = #{imei => IMEI, ip => IP, port => dmd_config:device_port(),
                    reported_ip => ReportedIP, status => Status,
                    last_seen => now_s(), calls => 1},
            ets:insert(?TAB, {IMEI, Map})
    end,
    {noreply, S}.

handle_info(_Info, S) -> {noreply, S}.

terminate(_Reason, _S) -> ok.

now_s() -> erlang:system_time(second).

parse_ip(Bin) ->
    case inet:parse_address(binary_to_list(Bin)) of
        {ok, Addr} -> Addr;
        {error, _} -> {127,0,0,1}
    end.
