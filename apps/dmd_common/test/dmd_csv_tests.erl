%%% @doc EUnit tests for the device inventory CSV (11-column format).
-module(dmd_csv_tests).
-include_lib("eunit/include/eunit.hrl").

generate_mix_test() ->
    Rows = dmd_csv:generate(3, 2, #{start_imei => 1, base_ip => {127,10,0,1},
                                    mgmt_port => 444, period_sec => 30}),
    ?assertEqual(5, length(Rows)),
    Types = [maps:get(device_type, R) || R <- Rows],
    ?assertEqual([1,1,1,2,2], Types),
    [First | _] = Rows,
    ?assertMatch(#{imei := <<"000000000000001">>, ip := {127,10,0,1},
                   port := 444, ssh_port := 22, device_type := 1, tls := false,
                   period_ms := 30000, stat_in_call := false,
                   login_name := <<"root">>,
                   login_pass := <<"admin">>, group := <<"Group-1">>}, First),
    %% Distinct IPs across the fleet.
    IPs = [maps:get(ip, R) || R <- Rows],
    ?assertEqual(5, length(lists:usort(IPs))).

generate_file_defaults_test() ->
    Path = filename:join(tmp_dir(), "devices_gen.csv"),
    ok = dmd_csv:generate_file(Path, 2, 1),
    {ok, Rows} = dmd_csv:read(Path),
    ?assertEqual(3, length(Rows)),
    ?assertEqual([1, 1, 2], [maps:get(device_type, R) || R <- Rows]),
    ?assertEqual(10000, maps:get(period_ms, hd(Rows))).

scale_distinct_ip_test() ->
    Rows = dmd_csv:generate_scale(6000, 4000, 10),
    ?assertEqual(10000, length(Rows)),
    ?assertEqual(6000, length([R || R <- Rows, maps:get(device_type, R) =:= 1])),
    ?assertEqual(4000, length([R || R <- Rows, maps:get(device_type, R) =:= 2])),
    IPs = [maps:get(ip, R) || R <- Rows],
    ?assertEqual(10000, length(lists:usort(IPs))),
    ?assert(lists:all(fun({127, _, _, _}) -> true; (_) -> false end, IPs)).

stat_in_call_generate_test() ->
    Rows = dmd_csv:generate(1, 2, #{start_imei => 1, stat_in_call => true}),
    ?assertEqual([false, true, true],
                 [maps:get(stat_in_call, R) || R <- Rows]),
    ?assertEqual([1, 2, 2], [maps:get(device_type, R) || R <- Rows]).

round_trip_test() ->
    Rows = dmd_csv:generate(2, 1, #{start_imei => 101000000000001,
                                    mgmt_port => 6060, period_sec => 5}),
    Path = filename:join(tmp_dir(), "devices_rt.csv"),
    ok = dmd_csv:write(Path, Rows),
    ?assertEqual({ok, Rows}, dmd_csv:read(Path)).

parse_example_test() ->
    Path = filename:join(tmp_dir(), "devices_ex.csv"),
    Content = <<"IMEI,IP,MgmtPort,PortSSH,DeviceType,TLSEnable,Reptime,"
                "LoginName,LoginPass,EquipmentGroup,StatInCall,Comments\n",
                "000000000000001,127.10.0.1,444,22,1,1,30,root,admin,Group-1,0,\n",
                "000000000000002,127.10.0.2,444,22,2,1,30,root,admin,Group-1,1,hi\n">>,
    ok = file:write_file(Path, Content),
    {ok, [R1, R2]} = dmd_csv:read(Path),
    ?assertMatch(#{imei := <<"000000000000001">>, ip := {127,10,0,1},
                   port := 444, device_type := 1, tls := true,
                   period_ms := 30000, stat_in_call := false, comments := <<>>}, R1),
    ?assertMatch(#{device_type := 2, stat_in_call := true, comments := <<"hi">>}, R2).

legacy_csv_without_stat_in_call_test() ->
    Path = filename:join(tmp_dir(), "devices_legacy.csv"),
    Content = <<"IMEI,IP,MgmtPort,PortSSH,DeviceType,TLSEnable,Reptime,"
                "LoginName,LoginPass,EquipmentGroup,Comments\n",
                "000000000000001,127.10.0.1,444,22,2,0,30,root,admin,Group-1,\n">>,
    ok = file:write_file(Path, Content),
    {ok, [R1]} = dmd_csv:read(Path),
    ?assertMatch(#{stat_in_call := false}, R1).

tmp_dir() ->
    Dir = filename:join("/tmp", "dmd_csv_test"),
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    Dir.
