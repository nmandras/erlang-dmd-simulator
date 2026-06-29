%%% @doc EUnit tests for WM-E checksums (golden vectors from plan Appendix C).
-module(wme_checksum_tests).
-include_lib("eunit/include/eunit.hrl").

xor_basic_test() ->
    %% bytes [01,02,03], XOR range [0..1] = 01 XOR 02 = 03
    ?assertEqual(16#03, wme_checksum:xor_checksum(<<16#01,16#02,16#03>>, 0, 1)).

xor_resp68_test() ->
    %% Real 0x68 response — XOR [2..-1] = 0xCF
    R = <<16#1B,16#16,16#68,16#FF,16#FF,16#09,16#0C,16#4B,16#E9,16#CF>>,
    ?assertEqual(16#CF, wme_checksum:xor_checksum(R, 2, -1)).

xor_start_read_test() ->
    %% Start config read default — XOR [2..0] = 0x67
    SR = <<16#1B,16#16,16#67,16#FF,16#FF,16#00>>,
    ?assertEqual(16#67, wme_checksum:xor_checksum(SR, 2, 0)).

fletcher_test() ->
    %% 1,2,3,4 -> msb/lsb progression -> {10, 20}
    ?assertEqual({10, 20}, wme_checksum:fletcher16(<<1,2,3,4>>)),
    ?assertEqual({0, 0}, wme_checksum:fletcher16(<<>>)).
