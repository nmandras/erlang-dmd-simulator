%%% @doc Per-device supervisor: the agent and its inbound listener.
%%%
%%% Strategy is `one_for_all' because the two are coupled — if either dies the
%%% device is restarted as a unit, returning to a clean state.
-module(device_instance_sup).
-behaviour(supervisor).

-export([start_link/3, init/1, agent_pid/1]).

start_link(IMEI, IP, Port) ->
    supervisor:start_link(?MODULE, [IMEI, IP, Port]).

init([IMEI, IP, Port]) ->
    SupFlags = #{strategy => one_for_all, intensity => 5, period => 10},
    Children = [
        %% Agent first so it is registered before the listener serves commands.
        #{id => agent,
          start => {device_agent, start_link, [IMEI, IP, Port]}},
        #{id => listener,
          start => {device_listener, start_link, [self(), Port, IP]}}
    ],
    {ok, {SupFlags, Children}}.

%% Resolve the agent pid of a device subtree. Must be called *after* init
%% completes (e.g. from a connection handler), never from a child's init,
%% otherwise it would deadlock on the still-busy supervisor.
-spec agent_pid(pid()) -> pid() | undefined.
agent_pid(SupPid) ->
    case lists:keyfind(agent, 1, supervisor:which_children(SupPid)) of
        {agent, Pid, _, _} when is_pid(Pid) -> Pid;
        _ -> undefined
    end.
