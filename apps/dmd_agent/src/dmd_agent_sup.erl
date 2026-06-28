%%% @doc Top-level supervisor of the agent application.
-module(dmd_agent_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{id => device_sup,
          start => {device_sup, start_link, []},
          type => supervisor,
          restart => permanent}
    ],
    {ok, {SupFlags, Children}}.
