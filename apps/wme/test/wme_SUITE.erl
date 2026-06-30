%%% @doc Client <-> simulator integration: a full IEC handshake + multi-packet
%%% config read over a real TCP socket, verifying the Fletcher-checked blob.
-module(wme_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).
-export([read_roundtrip/1, unknown_option/1, syslog_roundtrip/1, syslog_empty/1]).

-define(IP, {127,0,0,1}).
-define(IDENT, <<"/ELS5\\3 5.3.59.0 118\r\n">>).

all() ->
    [read_roundtrip, unknown_option, syslog_roundtrip, syslog_empty].

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

syslog_roundtrip(_Config) ->
    Port = 19997,
    Line1 = wme_syslog:format_entry(#{message_id => 1, payload => <<"5.3.61.0, 1">>}),
    Line2 = wme_syslog:format_entry(#{message_id => 13, payload => <<>>}),
    Blob = <<Line1/binary, Line2/binary>>,
    start_server(Port, fun(16#FF) -> {ok, <<"cfg">>}; (_) -> error end,
                 fun() -> {ok, Blob} end),
    ?assertEqual({ok, Blob}, wme_client:read_syslog(?IP, Port, 0, 5000)),
    {ok, Entries} = wme_syslog:parse_blob(Blob),
    ?assertEqual(2, length(Entries)).

syslog_empty(_Config) ->
    Port = 19996,
    start_server(Port, fun(16#FF) -> {ok, <<"cfg">>}; (_) -> error end,
                 fun() -> empty end),
    ?assertEqual({ok, <<>>}, wme_client:read_syslog(?IP, Port, 0, 5000)).

%% Spawn a one-shot WM-E simulator server bound to Port; returns once it is
%% listening so the client can connect.
start_server(Port, Provider) ->
    start_server(Port, Provider, fun() -> empty end).

start_server(Port, Provider, SyslogProvider) ->
    Parent = self(),
    spawn(fun() ->
        {ok, LSock} = wme_transport:listen(Port, ?IP),
        Parent ! ready,
        {ok, Sock} = wme_transport:accept(LSock),
        wme_sim_device:serve(Sock, ?IDENT, 256, Provider, SyslogProvider, 5000),
        wme_transport:close(Sock),
        wme_transport:close(LSock)
    end),
    receive ready -> ok after 2000 -> error(server_not_ready) end.
