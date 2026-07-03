%%% @doc IEC 62056-21 identification handshake (plan §3), line-based.
-module(wme_handshake).

-include("wme_constants.hrl").

-export([client/2, server/3]).

%% Client (WMETerm): probe, read ident, ack with 059, read device 059.
%% Returns the negotiated chunk version derived from the ident string.
-spec client(gen_tcp:socket(), timeout()) ->
          {ok, v1 | v2, binary()} | {error, term()}.
client(Sock, Timeout) ->
    ok = wme_transport:send(Sock, ?IEC_PROBE),
    case wme_transport:recv_line(Sock, Timeout) of
        {ok, Ident} ->
            ok = wme_transport:send(Sock, ?IEC_ACK),
            case wme_transport:recv_line(Sock, Timeout) of
                {ok, _Ack059} -> {ok, wme_codec:detect_version(Ident), Ident};
                Err -> Err
            end;
        Err ->
            Err
    end.

%% Device (simulator): read probe, send ident, read ack, echo ack (06 + 059).
-spec server(gen_tcp:socket(), binary(), timeout()) -> ok | {error, term()}.
server(Sock, Ident, Timeout) ->
    case wme_transport:recv_line(Sock, Timeout) of
        {ok, _Probe} ->
            ok = wme_transport:send(Sock, Ident),
            case wme_transport:recv_line(Sock, Timeout) of
                {ok, _Ack} -> wme_transport:send(Sock, ?IEC_ACK);
                Err -> Err
            end;
        Err ->
            Err
    end.
