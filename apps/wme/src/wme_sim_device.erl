%%% @doc WM-E device simulator: serve one accepted connection. Performs the IEC
%%% handshake, then answers config-read requests (0x67 start, 0x70 packets) from
%%% blobs supplied by a provider fun. Scope: handshake + read (no write/syslog).
-module(wme_sim_device).

-include("wme_constants.hrl").

-export([serve/5]).

-type provider() :: fun((byte()) -> {ok, binary()} | error).

%% Provider(Option) -> {ok, Blob} | error. Chunk is 256 (V1) or 1024 (V2) and
%% must be consistent with Ident's advertised version.
-spec serve(gen_tcp:socket(), binary(), pos_integer(), provider(), timeout()) -> ok.
serve(Sock, Ident, Chunk, Provider, Timeout) ->
    case wme_handshake:server(Sock, Ident, Timeout) of
        ok ->
            ok = wme_transport:set_raw(Sock),
            loop(Sock, Chunk, Provider, Timeout, undefined);
        _ ->
            ok
    end.

loop(Sock, Chunk, Provider, Timeout, Blob) ->
    case wme_transport:recv_exact(Sock, 6, Timeout) of
        {ok, <<?WME_H1, ?WME_H2, ?CMD_START_READ, 16#FF, Option, _Chk>>} ->
            case Provider(Option) of
                {ok, B} ->
                    wme_transport:send(Sock, wme_codec:build_read_header(B, Chunk)),
                    loop(Sock, Chunk, Provider, Timeout, B);
                error ->
                    %% E2 device error (unknown/unsupported object)
                    wme_transport:send(Sock, <<?WME_DEVICE_ERR, $E, $2>>),
                    loop(Sock, Chunk, Provider, Timeout, Blob)
            end;
        {ok, <<?WME_H1, ?WME_H2, ?CMD_READ_PKT, Hi, Lo, _Chk>>} when is_binary(Blob) ->
            wme_transport:send(Sock, wme_codec:build_read_packet(Blob, Hi * 256 + Lo, Chunk)),
            loop(Sock, Chunk, Provider, Timeout, Blob);
        {ok, _Other} ->
            ok;
        {error, _} ->
            ok
    end.
