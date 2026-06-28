%%% @doc Application behaviour for the dmd simulator.
-module(dmd_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) ->
    dmd_sup:start_link().

stop(_State) ->
    ok.
