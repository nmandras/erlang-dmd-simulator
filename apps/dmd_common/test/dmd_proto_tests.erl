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
    ?assertEqual({call, <<"101000000000001">>, <<"127.0.0.2">>, <<>>},
                 dmd_proto:decode_request(Bin)).

call_with_stat_round_trip_test() ->
    Stat = <<"smp.firmware_version = 5.3.61.0\nSECSTAT:1\n">>,
    Bin = dmd_proto:encode_call(<<"101000000000001">>, {127,0,0,2}, Stat),
    ?assertEqual({call, <<"101000000000001">>, <<"127.0.0.2">>, Stat},
                 dmd_proto:decode_request(Bin)).

command_decode_test() ->
    ?assertEqual({command, stat}, dmd_proto:decode_request(<<"STAT">>)),
    ?assertEqual({command, reboot}, dmd_proto:decode_request(<<"REBOOT">>)),
    ?assertEqual({command, seclog}, dmd_proto:decode_request(<<"SECLOG">>)),
    ?assertEqual(<<"SECLOG">>, dmd_proto:encode_command(seclog)),
    ?assertEqual({command, {unknown, <<"NOPE">>}},
                 dmd_proto:decode_request(<<"NOPE">>)).

response_round_trip_test() ->
    ?assertEqual(<<"CALL:0">>, dmd_proto:encode_response(call, 0)),
    ?assertEqual(<<"REBOOT:1">>, dmd_proto:encode_response(reboot, 1)),
    ?assertEqual({<<"CALL">>, 0, <<>>}, dmd_proto:decode_response(<<"CALL:0">>)),
    ?assertEqual({<<"STAT">>, 0, <<"imei=1">>},
                 dmd_proto:decode_response(<<"STAT:0,imei=1">>)).

%% A rich STAT body (no numeric code) decodes as success with the whole body.
rich_stat_response_test() ->
    Rich = <<"STAT:smp.firmware_version = 5.3.61.0\n"
             "smp.battery = 4200, CAPACITY = 100\n"
             "RTC:2026-06-29T17:22:50+00:00\nUPTIME:516.00\nSECSTAT:1">>,
    {Name, Code, Body} = dmd_proto:decode_response(Rich),
    ?assertEqual(<<"STAT">>, Name),
    ?assertEqual(0, Code),
    ?assertEqual(match, case binary:match(Body, <<"smp.firmware_version">>) of
                            nomatch -> nomatch; _ -> match end),
    %% A rebooting device still reports a numeric failure code.
    ?assertEqual({<<"STAT">>, 1, <<"rebooting">>},
                 dmd_proto:decode_response(<<"STAT:1,rebooting">>)).

valid_imei_test() ->
    ?assert(dmd_proto:valid_imei(<<"101000000000001">>)),
    ?assertNot(dmd_proto:valid_imei(<<"12345">>)),
    ?assertNot(dmd_proto:valid_imei(<<"12345678901234x">>)).

malformed_test() ->
    ?assertEqual({error, malformed_call}, dmd_proto:decode_request(<<"CALL:x">>)),
    ?assertEqual({error, malformed_response}, dmd_proto:decode_response(<<"garbage">>)).
