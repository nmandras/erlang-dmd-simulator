%%% @doc WM-E client (WMETerm side): connect, IEC handshake, read a config blob.
-module(wme_client).

-export([read_config/4]).

%% Connect to a WM-E device, perform the handshake and read the blob for the
%% given option byte (16#FF config, 16#0D status, 16#0B meter).
-spec read_config(inet:socket_address(), inet:port_number(), byte(), timeout()) ->
          {ok, binary()} | {error, term()}.
read_config(Host, Port, Option, Timeout) ->
    case wme_transport:connect(Host, Port, Timeout) of
        {ok, Sock} ->
            Result = try do_read(Sock, Option, Timeout)
                     catch Class:Reason -> {error, {Class, Reason}}
                     end,
            wme_transport:close(Sock),
            Result;
        {error, Reason} ->
            {error, {connect_failed, Reason}}
    end.

do_read(Sock, Option, Timeout) ->
    case wme_handshake:client(Sock, Timeout) of
        {ok, Version, _Ident} ->
            ok = wme_transport:set_raw(Sock),
            Chunk = wme_codec:chunk_size(Version),
            ok = wme_transport:send(Sock, wme_codec:start_read(Option)),
            case wme_transport:recv_exact(Sock, 10, Timeout) of
                {ok, Hdr} -> read_body(Sock, Hdr, Chunk, Timeout);
                Err -> Err
            end;
        Err ->
            Err
    end.

read_body(Sock, Hdr, Chunk, Timeout) ->
    case wme_codec:parse_read_header(Hdr, Chunk) of
        {ok, #{size := Size, fletcher := Fletcher, packets := Packets}} ->
            Blob = read_loop(Sock, 0, Packets, Chunk, Timeout, <<>>),
            Trimmed = binary:part(Blob, 0, Size),
            verify(Trimmed, Fletcher);
        Err ->
            Err
    end.

read_loop(_Sock, I, Packets, _Chunk, _Timeout, Acc) when I >= Packets ->
    Acc;
read_loop(Sock, I, Packets, Chunk, Timeout, Acc) ->
    ok = wme_transport:send(Sock, wme_codec:read_packet(I)),
    {ok, Frame} = wme_transport:recv_exact(Sock, 5 + Chunk + 1, Timeout),
    {ok, _Idx, Data} = wme_codec:parse_read_packet(Frame, Chunk),
    read_loop(Sock, I + 1, Packets, Chunk, Timeout, <<Acc/binary, Data/binary>>).

verify(Blob, Expected) ->
    {FM, FL} = wme_checksum:fletcher16(Blob),
    case (FM bsl 8) bor FL of
        Expected -> {ok, Blob};
        Got -> {error, {fletcher_mismatch, Got, Expected}}
    end.
