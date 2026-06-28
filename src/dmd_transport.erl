%%% @doc Transport abstraction over `gen_tcp' and `ssl'.
%%%
%%% A socket handle is the tagged tuple `{gen_tcp, Sock} | {ssl, Sock}', so
%%% all callers (listeners, the periodic CALL client, the commander) are
%%% transport-agnostic. TLS is selected per call via the boolean argument,
%%% which the rest of the system derives from {@link dmd_config:tls_enabled/0}.
-module(dmd_transport).

-export([listen/3, accept/1, connect/4,
         send/2, recv/3, close/1,
         controlling_process/2, peername/1]).

-export_type([socket/0]).

-type socket() :: {gen_tcp, gen_tcp:socket()} | {ssl, ssl:sslsocket()}.

%% Raw framing: we prepend our own 2-byte little-endian length prefix
%% (see dmd_proto), so the socket itself must not do any packet framing.
base_opts() ->
    [binary, {packet, raw}, {active, false}, {reuseaddr, true}, {nodelay, true}].

-spec listen(inet:port_number(), [gen_tcp:listen_option()], boolean()) ->
          {ok, socket()} | {error, term()}.
listen(Port, ExtraOpts, false) ->
    case gen_tcp:listen(Port, base_opts() ++ ExtraOpts) of
        {ok, S} -> {ok, {gen_tcp, S}};
        Err -> Err
    end;
listen(Port, ExtraOpts, true) ->
    Opts = base_opts() ++ ExtraOpts ++ dmd_config:tls_listen_opts(),
    case ssl:listen(Port, Opts) of
        {ok, S} -> {ok, {ssl, S}};
        Err -> Err
    end.

-spec accept(socket()) -> {ok, socket()} | {error, term()}.
accept({gen_tcp, L}) ->
    case gen_tcp:accept(L) of
        {ok, S} -> {ok, {gen_tcp, S}};
        Err -> Err
    end;
accept({ssl, L}) ->
    case ssl:transport_accept(L) of
        {ok, T} ->
            case ssl:handshake(T) of
                {ok, S} -> {ok, {ssl, S}};
                Err -> Err
            end;
        Err -> Err
    end.

-spec connect(inet:socket_address(), inet:port_number(),
              [gen_tcp:connect_option()], boolean()) ->
          {ok, socket()} | {error, term()}.
connect(Host, Port, ExtraOpts, false) ->
    Opts = [binary, {packet, raw}, {active, false}, {nodelay, true}] ++ ExtraOpts,
    case gen_tcp:connect(Host, Port, Opts, 5000) of
        {ok, S} -> {ok, {gen_tcp, S}};
        Err -> Err
    end;
connect(Host, Port, ExtraOpts, true) ->
    Opts = [binary, {packet, raw}, {active, false}, {nodelay, true}]
        ++ ExtraOpts ++ dmd_config:tls_connect_opts(),
    case ssl:connect(Host, Port, Opts, 5000) of
        {ok, S} -> {ok, {ssl, S}};
        Err -> Err
    end.

-spec send(socket(), iodata()) -> ok | {error, term()}.
send({Mod, S}, Data) -> Mod:send(S, Data).

-spec recv(socket(), non_neg_integer(), timeout()) ->
          {ok, binary()} | {error, term()}.
recv({Mod, S}, Len, Timeout) -> Mod:recv(S, Len, Timeout).

-spec close(socket()) -> ok.
close({Mod, S}) -> Mod:close(S), ok.

-spec controlling_process(socket(), pid()) -> ok | {error, term()}.
controlling_process({Mod, S}, Pid) -> Mod:controlling_process(S, Pid).

-spec peername(socket()) -> {ok, {inet:ip_address(), inet:port_number()}} | {error, term()}.
peername({gen_tcp, S}) -> inet:peername(S);
peername({ssl, S}) -> ssl:peername(S).
