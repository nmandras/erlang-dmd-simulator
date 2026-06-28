%%% @doc EUnit tests for the wire protocol (framing + encode/decode).
-module(dmd_proto_tests).
-include_lib("eunit/include/eunit.hrl").

frame_is_little_endian_test() ->
    ?assertEqual(<<3, 0, "abc">>, dmd_proto:frame(<<"abc">>)).

frame_length_test() ->
    Payload = list_to_binary(lists:duplicate(258, $x)),
    <<Lo, Hi, _/binary>> = dmd_proto:frame(Payload),
    ?assertEqual({2, 1}, {Lo, Hi}).

call_round_trip_test() ->
    Bin = dmd_proto:encode_call(<<"101000000000001">>, {127,0,0,2}),
    ?assertEqual(<<"CALL:101000000000001,127.0.0.2">>, Bin),
    ?assertEqual({call, <<"101000000000001">>, <<"127.0.0.2">>},
                 dmd_proto:decode_request(Bin)).

command_decode_test() ->
    ?assertEqual({command, stat}, dmd_proto:decode_request(<<"STAT">>)),
    ?assertEqual({command, reboot}, dmd_proto:decode_request(<<"REBOOT">>)),
    ?assertEqual({command, {unknown, <<"NOPE">>}},
                 dmd_proto:decode_request(<<"NOPE">>)).

response_round_trip_test() ->
    ?assertEqual(<<"CALL:0">>, dmd_proto:encode_response(call, 0)),
    ?assertEqual(<<"REBOOT:1">>, dmd_proto:encode_response(reboot, 1)),
    ?assertEqual({<<"CALL">>, 0, <<>>}, dmd_proto:decode_response(<<"CALL:0">>)),
    ?assertEqual({<<"STAT">>, 0, <<"imei=1">>},
                 dmd_proto:decode_response(<<"STAT:0,imei=1">>)).

valid_imei_test() ->
    ?assert(dmd_proto:valid_imei(<<"101000000000001">>)),
    ?assertNot(dmd_proto:valid_imei(<<"12345">>)),
    ?assertNot(dmd_proto:valid_imei(<<"12345678901234x">>)).

malformed_test() ->
    ?assertEqual({error, malformed_call}, dmd_proto:decode_request(<<"CALL:x">>)),
    ?assertEqual({error, malformed_response}, dmd_proto:decode_response(<<"garbage">>)).
