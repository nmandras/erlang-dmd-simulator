%%% @doc Per-device supervisor: the agent and its inbound listener.
%%%
%%% Strategy is `one_for_all' because the two are coupled — if either dies the
%%% device is restarted as a unit, returning to a clean state.
-module(device_instance_sup).
-behaviour(supervisor).

-export([start_link/1, init/1, agent_pid/1]).

start_link(Spec) ->
    supervisor:start_link(?MODULE, [Spec]).

%% Every device runs the CALL client (device_agent); the inbound listener is
%% chosen by DeviceType: 1 = wmr text protocol, 2 = WM-E protocol.
init([Spec = #{imei := IMEI, ip := IP, port := Port, device_type := DType}]) ->
    SupFlags = #{strategy => one_for_all, intensity => 5, period => 10},
    Children = [
        %% Agent first so it is up before the listener serves commands.
        #{id => agent,
          start => {device_agent, start_link, [Spec]}},
        listener_child(DType, self(), IMEI, IP, Port)
    ],
    {ok, {SupFlags, Children}}.

listener_child(2, _Sup, IMEI, IP, Port) ->
    #{id => wme_listener,
      start => {device_wme_listener, start_link, [IMEI, IP, Port]}};
listener_child(_Wmr, Sup, IMEI, IP, Port) ->
    #{id => listener,
      start => {device_listener, start_link, [Sup, IMEI, IP, Port]}}.

%% Resolve the agent pid of a device subtree. Must be called *after* init
%% completes (e.g. from a connection handler), never from a child's init,
%% otherwise it would deadlock on the still-busy supervisor.
-spec agent_pid(pid()) -> pid() | undefined.
agent_pid(SupPid) ->
    case lists:keyfind(agent, 1, supervisor:which_children(SupPid)) of
        {agent, Pid, _, _} when is_pid(Pid) -> Pid;
        _ -> undefined
    end.
