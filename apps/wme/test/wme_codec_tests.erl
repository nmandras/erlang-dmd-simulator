%%% @doc EUnit tests for WM-E frame build/parse (plan Appendix C golden vectors).
-module(wme_codec_tests).
-include_lib("eunit/include/eunit.hrl").

start_read_test() ->
    ?assertEqual(<<16#1B,16#16,16#67,16#FF,16#FF,16#67>>, wme_codec:start_read(16#FF)),
    ?assertEqual(<<16#1B,16#16,16#67,16#FF,16#0A,16#92>>, wme_codec:start_read(16#0A)),
    ?assertEqual(<<16#1B,16#16,16#67,16#FF,16#06,16#9E>>, wme_codec:start_read(16#06)),
    ?assertEqual(<<16#1B,16#16,16#67,16#FF,16#04,16#9C>>, wme_codec:start_read(16#04)).

read_packet_test() ->
    ?assertEqual(<<16#1B,16#16,16#70,16#00,16#00,16#70>>, wme_codec:read_packet(0)),
    P = wme_codec:read_packet(16#55),
    ?assertEqual(<<16#1B,16#16,16#70,16#00,16#55>>, binary:part(P, 0, 5)).

parse_header_test() ->
    H = <<16#1B,16#16,16#68,16#FF,16#FF,16#09,16#0C,16#4B,16#E9,16#CF>>,
    {ok, M} = wme_codec:parse_read_header(H, 256),
    ?assertEqual(2316, maps:get(size, M)),
    ?assertEqual(16#4BE9, maps:get(fletcher, M)),
    ?assertEqual(10, maps:get(packets, M)),
    %% Real-device status read header echoes option 0x0A at byte index 4.
    StatusH = <<16#1B,16#16,16#68,16#FF,16#0A,16#02,16#C4,16#AC,16#DB,16#2C>>,
    {ok, SM} = wme_codec:parse_read_header(StatusH, 256),
    ?assertEqual(708, maps:get(size, SM)),
    ?assertEqual(3, maps:get(packets, SM)).

version_detect_test() ->
    ?assertEqual(v1, wme_codec:detect_version(<<"/ELS5\\3 5.3.59.0 118\r\n">>)),
    ?assertEqual(v2, wme_codec:detect_version(<<"/ELS5\\3 1K 5.3.59.0\r\n">>)).

roundtrip_test() ->
    Blob = binary:copy(<<"x">>, 300),
    {ok, M} = wme_codec:parse_read_header(wme_codec:build_read_header(Blob, 256, 16#FF), 256),
    ?assertEqual(300, maps:get(size, M)),
    ?assertEqual(2, maps:get(packets, M)),
    {ok, StatusM} = wme_codec:parse_read_header(
                      wme_codec:build_read_header(Blob, 256, 16#0A), 256),
    ?assertEqual(300, maps:get(size, StatusM)),
    {ok, 0, D0} = wme_codec:parse_read_packet(wme_codec:build_read_packet(Blob, 0, 256), 256),
    {ok, 1, D1} = wme_codec:parse_read_packet(wme_codec:build_read_packet(Blob, 1, 256), 256),
    ?assertEqual(256, byte_size(D0)),
    ?assertEqual(Blob, binary:part(<<D0/binary, D1/binary>>, 0, 300)).

bad_checksum_test() ->
    Bad = <<16#1B,16#16,16#68,16#FF,16#FF,16#09,16#0C,16#4B,16#E9,16#00>>,
    ?assertEqual({error, bad_checksum}, wme_codec:parse_read_header(Bad, 256)).

start_syslog_read_test() ->
    ?assertEqual(<<16#1B,16#16,16#50,16#FF,16#10,16#00,16#00,16#BF>>,
                 wme_codec:start_syslog_read(16#10, 0)).

syslog_header_roundtrip_test() ->
    Blob = iolist_to_binary([<<"<34>Jun 30 09:00:00 WM-E1S sec[1]: evt\n">>]),
    {ok, M} = wme_codec:parse_syslog_header(wme_codec:build_syslog_header(Blob)),
    ?assertEqual(byte_size(Blob), maps:get(size, M)),
    ?assertEqual(1, maps:get(packets, M)).
