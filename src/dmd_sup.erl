%%% @doc Top-level supervisor: the mock management server and the device fleet.
-module(dmd_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% Server side first: the registry must exist before devices register.
        #{id => mgmt_sup,
          start => {mgmt_sup, start_link, []},
          type => supervisor,
          restart => permanent},
        #{id => device_sup,
          start => {device_sup, start_link, []},
          type => supervisor,
          restart => permanent}
    ],
    {ok, {SupFlags, Children}}.
