%%% @doc Per-device supervisor: the agent and its inbound listener.
%%%
%%% Strategy is `one_for_all' because the two are coupled — if either dies the
%%% device is restarted as a unit, returning to a clean state.
-module(device_instance_sup).
-behaviour(supervisor).

-export([start_link/4, init/1, agent_pid/1]).

start_link(IMEI, IP, Port, PeriodMs) ->
    supervisor:start_link(?MODULE, [IMEI, IP, Port, PeriodMs]).

init([IMEI, IP, Port, PeriodMs]) ->
    SupFlags = #{strategy => one_for_all, intensity => 5, period => 10},
    Children = [
        %% Agent first so it is up before the listener serves commands.
        #{id => agent,
          start => {device_agent, start_link, [IMEI, IP, Port, PeriodMs]}},
        #{id => listener,
          start => {device_listener, start_link, [self(), IMEI, IP, Port]}}
    ] ++ wme_children(IMEI, IP),
    {ok, {SupFlags, Children}}.

%% Optional WM-E (config-read) listener on the device's IP:wme_port.
wme_children(IMEI, IP) ->
    case dmd_config:get(dmd_agent, wme_enabled, true) of
        true ->
            [#{id => wme_listener,
               start => {device_wme_listener, start_link, [IMEI, IP]}}];
        false ->
            []
    end.

%% Resolve the agent pid of a device subtree. Must be called *after* init
%% completes (e.g. from a connection handler), never from a child's init,
%% otherwise it would deadlock on the still-busy supervisor.
-spec agent_pid(pid()) -> pid() | undefined.
agent_pid(SupPid) ->
    case lists:keyfind(agent, 1, supervisor:which_children(SupPid)) of
        {agent, Pid, _, _} when is_pid(Pid) -> Pid;
        _ -> undefined
    end.
