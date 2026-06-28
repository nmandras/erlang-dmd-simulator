%%% @doc EUnit tests for the wire protocol (framing + encode/decode).
-module(dmd_proto_tests).
-include_lib("eunit/include/eunit.hrl").

frame_is_little_endian_test() ->
    %% 3-byte payload -> length prefix 0x03 0x00 (LSB first).
    ?assertEqual(<<3, 0, "abc">>, dmd_proto:frame(<<"abc">>)).

frame_length_test() ->
    %% 258 = 0x0102 -> prefix bytes 0x02 0x01 (little-endian).
    Payload = list_to_binary(lists:duplicate(258, $x)),
    <<Lo, Hi, _/binary>> = dmd_proto:frame(Payload),
    ?assertEqual({2, 1}, {Lo, Hi}).

call_round_trip_test() ->
    Bin = dmd_proto:encode_call(<<"123456789012345">>, {127,0,0,2}),
    ?assertEqual(<<"CALL: 123456789012345,127.0.0.2">>, Bin),
    ?assertEqual({call, <<"123456789012345">>, <<"127.0.0.2">>},
                 dmd_proto:decode_request(Bin)).

command_decode_test() ->
    ?assertEqual({command, stat}, dmd_proto:decode_request(<<"STAT">>)),
    ?assertEqual({command, reboot}, dmd_proto:decode_request(<<"REBOOT">>)),
    ?assertEqual({command, {unknown, <<"NOPE">>}},
                 dmd_proto:decode_request(<<"NOPE">>)).

encode_command_test() ->
    ?assertEqual(<<"STAT">>, dmd_proto:encode_command(stat)),
    ?assertEqual(<<"REBOOT">>, dmd_proto:encode_command(reboot)).

response_round_trip_test() ->
    ?assertEqual(<<"CALL:0">>, dmd_proto:encode_response(call, 0)),
    ?assertEqual(<<"REBOOT:1">>, dmd_proto:encode_response(reboot, 1)),
    ?assertEqual({<<"CALL">>, 0, <<>>},
                 dmd_proto:decode_response(<<"CALL:0">>)),
    ?assertEqual({<<"STAT">>, 0, <<"imei=1;state=running">>},
                 dmd_proto:decode_response(<<"STAT:0,imei=1;state=running">>)).

response_with_data_test() ->
    Bin = dmd_proto:encode_response(stat, 0, <<"uptime=5s">>),
    ?assertEqual(<<"STAT:0,uptime=5s">>, Bin),
    ?assertEqual({<<"STAT">>, 0, <<"uptime=5s">>}, dmd_proto:decode_response(Bin)).

valid_imei_test() ->
    ?assert(dmd_proto:valid_imei(<<"123456789012345">>)),
    ?assertNot(dmd_proto:valid_imei(<<"12345">>)),           %% too short
    ?assertNot(dmd_proto:valid_imei(<<"12345678901234x">>)), %% non-digit
    ?assertNot(dmd_proto:valid_imei("123456789012345")).     %% not a binary

malformed_test() ->
    ?assertEqual({error, malformed_call}, dmd_proto:decode_request(<<"CALL: nocomma">>)),
    ?assertEqual({error, malformed_response}, dmd_proto:decode_response(<<"garbage">>)).
