%%% @doc WM-E device simulator: serve one accepted connection. Performs the IEC
%%% handshake, then answers config-read (0x67/0x70) and syslog-read (0x50/0x70)
%%% requests from blobs supplied by provider funs.
-module(wme_sim_device).

-include("wme_constants.hrl").

-export([serve/5, serve/6]).

-type provider() :: fun((byte()) -> {ok, binary()} | error).
-type syslog_provider() :: fun(() -> {ok, binary()} | empty).

%% Backward-compatible entry without syslog support.
-spec serve(gen_tcp:socket(), binary(), pos_integer(), provider(), timeout()) -> ok.
serve(Sock, Ident, Chunk, Provider, Timeout) ->
    serve(Sock, Ident, Chunk, Provider, fun() -> empty end, Timeout).

-spec serve(gen_tcp:socket(), binary(), pos_integer(), provider(), syslog_provider(),
            timeout()) -> ok.
serve(Sock, Ident, Chunk, Provider, SyslogProvider, Timeout) ->
    case wme_handshake:server(Sock, Ident, Timeout) of
        ok ->
            ok = wme_transport:set_raw(Sock),
            loop(Sock, Chunk, Provider, SyslogProvider, Timeout, undefined);
        _ ->
            ok
    end.

loop(Sock, Chunk, Provider, SyslogProvider, Timeout, Blob) ->
    case wme_transport:recv_exact(Sock, 6, Timeout) of
        {ok, <<?WME_H1, ?WME_H2, ?CMD_START_READ, 16#FF, Option, _Chk>>} ->
            case Provider(Option) of
                {ok, B} ->
                    wme_transport:send(Sock, wme_codec:build_read_header(B, Chunk)),
                    loop(Sock, Chunk, Provider, SyslogProvider, Timeout, B);
                error ->
                    wme_transport:send(Sock, <<?WME_DEVICE_ERR, $E, $2>>),
                    loop(Sock, Chunk, Provider, SyslogProvider, Timeout, Blob)
            end;
        {ok, <<?WME_H1, ?WME_H2, ?CMD_SYSLOG_READ, 16#FF, _ReadId, _CntMSB>>} ->
            case wme_transport:recv_exact(Sock, 2, Timeout) of
                {ok, <<_CntLSB, _Chk>>} ->
                    case SyslogProvider() of
                        {ok, B} when byte_size(B) > 0 ->
                            wme_transport:send(Sock, wme_codec:build_syslog_header(B)),
                            loop(Sock, Chunk, Provider, SyslogProvider, Timeout, B);
                        _ ->
                            wme_transport:send(Sock, <<?WME_DEVICE_ERR, $E, $1>>),
                            loop(Sock, Chunk, Provider, SyslogProvider, Timeout, Blob)
                    end;
                {error, _} = Err ->
                    Err
            end;
        {ok, <<?WME_H1, ?WME_H2, ?CMD_READ_PKT, Hi, Lo, _Chk>>} when is_binary(Blob) ->
            wme_transport:send(Sock, wme_codec:build_read_packet(Blob, Hi * 256 + Lo, Chunk)),
            loop(Sock, Chunk, Provider, SyslogProvider, Timeout, Blob);
        {ok, _Other} ->
            ok;
        {error, _} ->
            ok
    end.
