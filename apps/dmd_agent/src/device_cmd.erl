%%% @doc Command dispatcher for a running device.
%%%
%%% Single extension point for everything a device can be asked to do. STAT and
%%% REBOOT are fully implemented; security-log retrieval, configuration apply
%%% and firmware upgrade are stubbed but wired in.
%%%
%%% Returns `{Code, Data, Action}' where Code is 0 (ok) / 1 (fail), Data is an
%%% optional binary appended to the response, and Action tells the agent
%%% whether to change state (e.g. begin a reboot).
-module(device_cmd).

-export([handle/2]).

-type code() :: 0 | 1.
-type action() :: none | reboot.
-export_type([code/0, action/0]).

-spec handle(term(), map()) -> {code(), binary(), action()}.
handle(stat, Data) ->
    {0, device_agent:status_line(Data), none};
handle(reboot, _Data) ->
    {0, <<>>, reboot};
handle({config, _Payload}, _Data) ->
    {0, <<"config-applied">>, none};
handle({firmware, _Payload}, _Data) ->
    {0, <<"firmware-staged">>, none};
handle(seclogs, _Data) ->
    {0, <<"no-events">>, none};
handle({unknown, _Raw}, _Data) ->
    {1, <<"unknown-command">>, none}.
