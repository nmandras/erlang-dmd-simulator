%%% @doc Client <-> simulator integration: a full IEC handshake + multi-packet
%%% config read over a real TCP socket, verifying the Fletcher-checked blob.
-module(wme_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).
-export([read_roundtrip/1, unknown_option/1]).

-define(IP, {127,0,0,1}).
-define(IDENT, <<"/ELS5\\3 5.3.59.0 118\r\n">>).

all() ->
    [read_roundtrip, unknown_option].

read_roundtrip(_Config) ->
    Port = 19998,
    Blob = binary:copy(<<"ABCDEFGH">>, 100),  %% 800 bytes -> 4 V1 packets
    start_server(Port, fun(16#FF) -> {ok, Blob}; (_) -> error end),
    ?assertEqual({ok, Blob}, wme_client:read_config(?IP, Port, 16#FF, 5000)).

unknown_option(_Config) ->
    Port = 19999,
    start_server(Port, fun(16#FF) -> {ok, <<"cfg">>}; (_) -> error end),
    %% An unsupported option yields a device error, surfaced as an error tuple.
    ?assertMatch({error, _}, wme_client:read_config(?IP, Port, 16#0D, 1000)).

%% Spawn a one-shot WM-E simulator server bound to Port; returns once it is
%% listening so the client can connect.
start_server(Port, Provider) ->
    Parent = self(),
    spawn(fun() ->
        {ok, LSock} = wme_transport:listen(Port, ?IP),
        Parent ! ready,
        {ok, Sock} = wme_transport:accept(LSock),
        wme_sim_device:serve(Sock, ?IDENT, 256, Provider, 5000),
        wme_transport:close(Sock),
        wme_transport:close(LSock)
    end),
    receive ready -> ok after 2000 -> error(server_not_ready) end.
