%%% @doc EUnit tests for WM-E syslog line format and parsing.
-module(wme_syslog_tests).
-include_lib("eunit/include/eunit.hrl").

golden_line_test() ->
    Line = <<"<31>1 2026-05-22T08:29:50.000Z 1S1R WM-E1S_5.3.59.0 118 0 - BOM2 3">>,
    {ok, E} = wme_syslog:parse_line(Line),
    ?assertEqual(31, maps:get(pri, E)),
    ?assertEqual(<<"1S1R">>, maps:get(hostname, E)),
    ?assertEqual(118, maps:get(hw_id, E)),
    ?assertEqual(0, maps:get(message_id, E)),
    ?assertEqual(<<"BOM2 3">>, maps:get(payload, E)).

format_roundtrip_test() ->
    Opts = #{message_id => 1, payload => <<"5.3.61.0, 1">>,
             timestamp => <<"2026-05-22T08:29:50.000Z">>},
    Line = wme_syslog:format_entry(Opts),
    {ok, E} = wme_syslog:parse_line(Line),
    ?assertEqual(1, maps:get(message_id, E)),
    ?assertEqual(<<"5.3.61.0, 1">>, maps:get(payload, E)),
    ?assertEqual(<<"MESSAGE_DEVICE_POWER_UP">>,
                 wme_syslog:message_name(0, maps:get(message_id, E))).

parse_blob_test() ->
    Blob = iolist_to_binary([
        wme_syslog:format_entry(#{message_id => 1, payload => <<"5.3.61.0, 1">>}),
        wme_syslog:format_entry(#{message_id => 13, payload => <<>>}),
        <<0, 0, 0>>
    ]),
    {ok, Entries} = wme_syslog:parse_blob(Blob),
    ?assertEqual(2, length(Entries)).
