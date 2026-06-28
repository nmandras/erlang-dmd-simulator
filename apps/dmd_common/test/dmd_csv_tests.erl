%%% @doc EUnit tests for the device inventory CSV.
-module(dmd_csv_tests).
-include_lib("eunit/include/eunit.hrl").

generate_test() ->
    Rows = dmd_csv:generate(10, 101000000000001, 2, 6000, 10),
    ?assertEqual(10, length(Rows)),
    [First | _] = Rows,
    ?assertMatch(#{imei := <<"101000000000001">>, ip := {127,0,0,2},
                   port := 6000, callperiod_ms := 10000}, First),
    Last = lists:last(Rows),
    ?assertMatch(#{imei := <<"101000000000010">>, ip := {127,0,0,11}}, Last).

generate_scale_test() ->
    Rows = dmd_csv:generate_scale(10000, 101000000000001, 6000, 10),
    ?assertEqual(10000, length(Rows)),
    IPs = [maps:get(ip, R) || R <- Rows],
    %% Every device gets a distinct, in-range loopback IP.
    ?assertEqual(10000, length(lists:usort(IPs))),
    ?assert(lists:all(fun({127, _, _, _}) -> true; (_) -> false end, IPs)),
    ?assertEqual({127,0,0,2}, dmd_csv:index_ip(2)),
    ?assertEqual({127,0,1,0}, dmd_csv:index_ip(256)).

round_trip_test() ->
    Rows = dmd_csv:generate(3, 101000000000001, 2, 6000, 10),
    Path = filename:join(tmp_dir(), "devices_rt.csv"),
    ok = dmd_csv:write(Path, Rows),
    ?assertEqual({ok, Rows}, dmd_csv:read(Path)).

parse_skips_header_and_comments_test() ->
    Path = filename:join(tmp_dir(), "devices_hc.csv"),
    Content = <<"imei,ip,port,callperiod\n",
                "# a comment\n",
                "\n",
                "101000000000001,127.0.0.2,6000,10\n">>,
    ok = file:write_file(Path, Content),
    {ok, [Row]} = dmd_csv:read(Path),
    ?assertMatch(#{imei := <<"101000000000001">>, ip := {127,0,0,2},
                   port := 6000, callperiod_ms := 10000}, Row).

tmp_dir() ->
    Dir = filename:join("/tmp", "dmd_csv_test"),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    Dir.
