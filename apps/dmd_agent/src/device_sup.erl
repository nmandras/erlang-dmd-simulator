%%% @doc Dynamic supervisor for the device fleet.
%%%
%%% Each child is a per-device subtree ({@link device_instance_sup}). A public
%%% ETS table maps IMEI -> instance-supervisor pid so devices can be stopped
%%% by IMEI.
-module(device_sup).
-behaviour(supervisor).

-export([start_link/0, init/1, start_device/4, stop_device/1, count/0]).

-define(TAB, dmd_agent_devices).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    case ets:info(?TAB) of
        undefined -> ets:new(?TAB, [named_table, set, public]);
        _ -> ok
    end,
    SupFlags = #{strategy => simple_one_for_one, intensity => 10, period => 10},
    Child = #{id => device_instance_sup,
              start => {device_instance_sup, start_link, []},
              restart => transient,
              type => supervisor},
    {ok, {SupFlags, [Child]}}.

-spec start_device(binary(), inet:ip_address(), inet:port_number(),
                   non_neg_integer()) -> {ok, pid()} | {error, term()}.
start_device(IMEI, IP, Port, PeriodMs) ->
    case ets:member(?TAB, IMEI) of
        true ->
            {error, already_started};
        false ->
            case supervisor:start_child(?MODULE, [IMEI, IP, Port, PeriodMs]) of
                {ok, Pid} ->
                    ets:insert(?TAB, {IMEI, Pid}),
                    {ok, Pid};
                Err ->
                    Err
            end
    end.

-spec stop_device(binary()) -> ok | {error, term()}.
stop_device(IMEI) ->
    case ets:lookup(?TAB, IMEI) of
        [{_, Pid}] ->
            Result = supervisor:terminate_child(?MODULE, Pid),
            ets:delete(?TAB, IMEI),
            Result;
        [] ->
            {error, not_found}
    end.

-spec count() -> non_neg_integer().
count() ->
    case ets:info(?TAB, size) of
        undefined -> 0;
        N -> N
    end.
