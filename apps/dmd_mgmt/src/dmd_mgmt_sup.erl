%%% @doc Top-level supervisor of the management server application.
-module(dmd_mgmt_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% Metrics first so it shuts down last and can report on termination.
        #{id => dmd_metrics,
          start => {dmd_metrics, start_link, [dmd_mgmt, [dmd, mgmt]]}},
        %% Registry before the listener/commander/driver that use it.
        #{id => mgmt_registry, start => {mgmt_registry, start_link, []}},
        #{id => mgmt_commander, start => {mgmt_commander, start_link, []}},
        #{id => mgmt_listener, start => {mgmt_listener, start_link, []}},
        #{id => mgmt_driver, start => {mgmt_driver, start_link, []}}
    ],
    {ok, {SupFlags, Children}}.
