%%% @doc WM-E frame build/parse for the config-read pipeline (plan §7).
-module(wme_codec).

-include("wme_constants.hrl").

-export([chunk_size/1, detect_version/1,
         start_read/1, parse_read_header/2,
         read_packet/1, parse_read_packet/2,
         build_read_header/2, build_read_header/3, build_read_packet/3,
         start_syslog_read/2, parse_syslog_header/1,
         build_syslog_header/1]).

-spec chunk_size(v1 | v2) -> pos_integer().
chunk_size(v2) -> ?CHUNK_V2;
chunk_size(_) -> ?CHUNK_V1.

%% V2 if the ident advertises 1K/1024 chunking, else V1 (plan §3.3).
-spec detect_version(binary()) -> v1 | v2.
detect_version(Ident) ->
    Up = string:uppercase(Ident),
    case binary:match(Up, [<<"1K">>, <<"1024">>]) of
        nomatch -> v1;
        _ -> v2
    end.

%%====================================================================
%% Client side (WMETerm)
%%====================================================================

%% Start-read request: 1B 16 67 FF <option> <xor>.
-spec start_read(byte()) -> binary().
start_read(Option) ->
    Inner = <<?CMD_START_READ, 16#FF, Option>>,
    <<?WME_H1, ?WME_H2, Inner/binary, (wme_checksum:xor_checksum(Inner, 0, 0))>>.

%% Parse the 10-byte 0x68 response -> #{size, fletcher, packets}.
-spec parse_read_header(binary(), pos_integer()) ->
          {ok, map()} | {error, term()}.
parse_read_header(<<?WME_H1, ?WME_H2, ?CMD_READ_HDR, 16#FF, _Option,
                    SzMSB, SzLSB, FlMSB, FlLSB, Chk>> = Frame, Chunk) ->
    case wme_checksum:xor_checksum(Frame, 2, -1) of
        Chk ->
            Size = SzMSB * Chunk + SzLSB,
            Packets = case Size of
                          0 -> 0;
                          _ -> (Size + Chunk - 1) div Chunk
                      end,
            {ok, #{size => Size,
                   fletcher => (FlMSB bsl 8) bor FlLSB,
                   packets => Packets}};
        _ ->
            {error, bad_checksum}
    end;
parse_read_header(_Other, _Chunk) ->
    {error, bad_read_header}.

%% Read-packet request for 0-based index: 1B 16 70 <hi> <lo> <xor>.
-spec read_packet(non_neg_integer()) -> binary().
read_packet(Index) ->
    Inner = <<?CMD_READ_PKT, (Index bsr 8):8, (Index band 16#FF):8>>,
    <<?WME_H1, ?WME_H2, Inner/binary, (wme_checksum:xor_checksum(Inner, 0, 0))>>.

%% Parse a 0x71 data frame -> {ok, Index, ChunkData}. Frame is 5 + Chunk + 1.
-spec parse_read_packet(binary(), pos_integer()) ->
          {ok, non_neg_integer(), binary()} | {error, term()}.
parse_read_packet(<<?WME_H1, ?WME_H2, ?CMD_READ_RSP, Hi, Lo, Rest/binary>> = Frame,
                  Chunk) when byte_size(Rest) =:= Chunk + 1 ->
    Chk = binary:at(Rest, Chunk),
    case wme_checksum:xor_checksum(Frame, 2, -1) of
        Chk -> {ok, Hi * 256 + Lo, binary:part(Rest, 0, Chunk)};
        _ -> {error, bad_checksum}
    end;
parse_read_packet(_Other, _Chunk) ->
    {error, bad_read_packet}.

%% Start-syslog-read request: 1B 16 50 FF <read_id> <count_hi> <count_lo> <xor>.
-spec start_syslog_read(byte(), non_neg_integer()) -> binary().
start_syslog_read(ReadId, Count) ->
    Inner = <<?CMD_SYSLOG_READ, 16#FF, ReadId, (Count bsr 8):8, (Count band 16#FF):8>>,
    <<?WME_H1, ?WME_H2, Inner/binary, (wme_checksum:xor_checksum(Inner, 0, 0))>>.

%% Parse the 10-byte 0x51 response (always 256-byte syslog packets).
-spec parse_syslog_header(binary()) -> {ok, map()} | {error, term()}.
parse_syslog_header(<<?WME_H1, ?WME_H2, ?CMD_SYSLOG_HDR, 16#FF, 16#FF,
                    SzMSB, SzLSB, FlMSB, FlLSB, Chk>> = Frame) ->
    case wme_checksum:xor_checksum(Frame, 2, -1) of
        Chk ->
            Chunk = ?CHUNK_V1,
            Size = SzMSB * Chunk + SzLSB,
            Packets = case Size of
                          0 -> 0;
                          _ -> (Size + Chunk - 1) div Chunk
                      end,
            {ok, #{size => Size,
                   fletcher => (FlMSB bsl 8) bor FlLSB,
                   packets => Packets}};
        _ ->
            {error, bad_checksum}
    end;
parse_syslog_header(_Other) ->
    {error, bad_syslog_header}.

%%====================================================================
%% Device side (simulator)
%%====================================================================

%% Build the 0x68 start-read response for a blob. Echoes the read option at
%% byte index 4 (0xFF for full config, 0x0A for status, etc.).
-spec build_read_header(binary(), pos_integer()) -> binary().
build_read_header(Blob, Chunk) ->
    build_read_header(Blob, Chunk, 16#FF).

-spec build_read_header(binary(), pos_integer(), byte()) -> binary().
build_read_header(Blob, Chunk, Option) ->
    Size = byte_size(Blob),
    {FM, FL} = wme_checksum:fletcher16(Blob),
    Inner = <<?CMD_READ_HDR, 16#FF, Option, (Size div Chunk), (Size rem Chunk), FM, FL>>,
    <<?WME_H1, ?WME_H2, Inner/binary, (wme_checksum:xor_checksum(Inner, 0, 0))>>.

%% Build the 0x71 data frame for packet Index (zero-padded to Chunk).
-spec build_read_packet(binary(), non_neg_integer(), pos_integer()) -> binary().
build_read_packet(Blob, Index, Chunk) ->
    Offset = Index * Chunk,
    Take = min(Chunk, max(0, byte_size(Blob) - Offset)),
    Raw = binary:part(Blob, Offset, Take),
    Data = <<Raw/binary, 0:((Chunk - Take) * 8)>>,
    Inner = <<?CMD_READ_RSP, (Index bsr 8):8, (Index band 16#FF):8, Data/binary>>,
    <<?WME_H1, ?WME_H2, Inner/binary, (wme_checksum:xor_checksum(Inner, 0, 0))>>.

%% Build the 0x51 start-syslog-read response for a blob.
-spec build_syslog_header(binary()) -> binary().
build_syslog_header(Blob) ->
    Size = byte_size(Blob),
    Chunk = ?CHUNK_V1,
    {FM, FL} = wme_checksum:fletcher16(Blob),
    Inner = <<?CMD_SYSLOG_HDR, 16#FF, 16#FF, (Size div Chunk), (Size rem Chunk), FM, FL>>,
    <<?WME_H1, ?WME_H2, Inner/binary, (wme_checksum:xor_checksum(Inner, 0, 0))>>.
