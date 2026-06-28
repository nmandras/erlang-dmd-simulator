%%% @doc Top-level supervisor of the agent application.
-module(dmd_agent_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% Metrics first so it shuts down last and can report on termination.
        #{id => dmd_metrics,
          start => {dmd_metrics, start_link, [dmd_agent, [dmd, agent]]}},
        #{id => device_sup,
          start => {device_sup, start_link, []},
          type => supervisor,
          restart => permanent}
    ],
    {ok, {SupFlags, Children}}.
