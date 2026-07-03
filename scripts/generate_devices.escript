#!/usr/bin/env escript
%% -*- erlang -*-
%% Generate config/devices.csv for the dmd simulator fleet.
%%
%% Usage:
%%   generate_devices.escript WMR WME [-o PATH] [--reptime SEC] [--mgmt-port PORT]
%%                                  [--start-imei N] [--base-ip A.B.C.D]
%%                                  [--stat-in-call 0|1]
%%
%% Examples:
%%   generate_devices.escript 8 2
%%   generate_devices.escript 0 10 -o config/devices.csv
%%   generate_devices.escript 100 50 --reptime 30 --stat-in-call 1
-mode(compile).

main(["-h" | _]) -> usage(), halt(0);
main(["--help" | _]) -> usage(), halt(0);
main(Argv) ->
    case parse_args(Argv) of
        {error, Msg} ->
            io:format(standard_error, "ERROR: ~s~n", [Msg]),
            usage(),
            halt(1);
        {ok, Config} ->
            case ensure_dmd_common() of
                ok ->
                    run(Config);
                {error, Reason} ->
                    io:format(standard_error, "ERROR: ~p~n", [Reason]),
                    halt(1)
            end
    end.

run(#{wmr := Wmr, wme := Wme, path := Path, opts := Opts}) ->
    Total = Wmr + Wme,
    StatInCall = maps:get(stat_in_call, Opts, false),
    case dmd_csv:generate_file(Path, Wmr, Wme, Opts) of
        ok ->
            {ok, Rows} = dmd_csv:read(Path),
            [First | _] = Rows,
            Last = lists:last(Rows),
            StatCount = length([R || R <- Rows, maps:get(stat_in_call, R)]),
            io:format(">> Wrote ~p devices (~p WMR, ~p WME) to ~s~n",
                      [Total, Wmr, Wme, Path]),
            io:format("   IMEI range: ~s .. ~s~n",
                      [maps:get(imei, First), maps:get(imei, Last)]),
            io:format("   IP range:   ~s .. ~s~n",
                      [ip_str(maps:get(ip, First)), ip_str(maps:get(ip, Last))]),
            case StatInCall of
                true ->
                    io:format("   StatInCall: ~p WME device(s) embed status in CALL~n",
                              [StatCount]);
                false ->
                    ok
            end,
            halt(0);
        {error, Reason} ->
            io:format(standard_error, "ERROR: ~p~n", [Reason]),
            halt(1)
    end.

parse_args([WmrS, WmeS | Rest]) ->
    try
        Wmr = list_to_integer(WmrS),
        Wme = list_to_integer(WmeS),
        parse_opts(Rest, #{wmr => Wmr, wme => Wme,
                           path => "config/devices.csv", opts => #{}})
    catch _:_ ->
        {error, "WMR and WME must be non-negative integers"}
    end;
parse_args(_) ->
    {error, "expected: WMR WME [options]"}.

parse_opts([], C) ->
    case maps:get(wmr, C) + maps:get(wme, C) of
        0 -> {error, "at least one device is required (WMR + WME >= 1)"};
        _ -> {ok, C}
    end;
parse_opts(["-o", Path | Rest], C) ->
    parse_opts(Rest, C#{path => Path});
parse_opts(["--reptime", S | Rest], C) ->
    Opts = maps:put(period_sec, list_to_integer(S), maps:get(opts, C)),
    parse_opts(Rest, C#{opts => Opts});
parse_opts(["--mgmt-port", S | Rest], C) ->
    Opts = maps:put(mgmt_port, list_to_integer(S), maps:get(opts, C)),
    parse_opts(Rest, C#{opts => Opts});
parse_opts(["--start-imei", S | Rest], C) ->
    Opts = maps:put(start_imei, list_to_integer(S), maps:get(opts, C)),
    parse_opts(Rest, C#{opts => Opts});
parse_opts(["--stat-in-call", S | Rest], C) ->
    case parse_bool(S) of
        {ok, Bool} ->
            Opts = maps:put(stat_in_call, Bool, maps:get(opts, C)),
            parse_opts(Rest, C#{opts => Opts});
        error ->
            {error, "invalid --stat-in-call, expected 0 or 1"}
    end;
parse_opts(["--base-ip", Ip | Rest], C) ->
    case inet:parse_address(Ip) of
        {ok, Addr} ->
            Opts = maps:put(base_ip, Addr, maps:get(opts, C)),
            parse_opts(Rest, C#{opts => Opts});
        {error, _} ->
            {error, "invalid --base-ip, expected A.B.C.D"}
    end;
parse_opts(["-h" | _], _) ->
    usage(),
    halt(0);
parse_opts(["--help" | _], _) ->
    usage(),
    halt(0);
parse_opts([Arg | _], _) ->
    {error, "unknown argument: " ++ Arg}.

parse_bool("0") -> {ok, false};
parse_bool("1") -> {ok, true};
parse_bool(_) -> error.

ensure_dmd_common() ->
    Script = filename:absname(escript:script_name()),
    Dir = filename:dirname(Script),
    Candidates = [
        filename:join(Dir, "lib/dmd_common/ebin"),
        filename:join(Dir, "_build/default/lib/dmd_common/ebin"),
        filename:join(Dir, "../lib/dmd_common/ebin"),
        filename:join(Dir, "../_build/default/lib/dmd_common/ebin"),
        filename:join(Dir, "../../_build/default/lib/dmd_common/ebin")
    ],
    case first_existing(Candidates) of
        {ok, Ebin} ->
            code:add_pathz(Ebin),
            case code:ensure_loaded(dmd_csv) of
                {module, dmd_csv} -> ok;
                _ -> {error, {dmd_csv_not_found, Ebin}}
            end;
        error ->
            {error, {dmd_common_ebin_not_found, Candidates}}
    end.

first_existing([P | Ps]) ->
    case filelib:is_dir(P) of
        true -> {ok, filename:absname(P)};
        false -> first_existing(Ps)
    end;
first_existing([]) -> error.

ip_str({A, B, C, D}) ->
    io_lib:format("~b.~b.~b.~b", [A, B, C, D]).

usage() ->
    io:format(
      "Usage: ~s WMR WME [-o PATH] [--reptime SEC] [--mgmt-port PORT]~n"
      "                   [--start-imei N] [--base-ip A.B.C.D]~n"
      "                   [--stat-in-call 0|1]~n~n"
      "  WMR  number of WMR devices (DeviceType 1)~n"
      "  WME  number of WME devices (DeviceType 2)~n"
      "  -o   output CSV path (default: config/devices.csv)~n"
      "  --stat-in-call  1 sets StatInCall=1 on all WME rows (default 0)~n",
      [filename:basename(escript:script_name())]).
