%%% @doc WM-E syslog entry format and parsing (plans/Syslog.md + wire capture).
%%%
%%% Stored syslog lines use an RFC5424-like WM-E layout:
%%%
%%%   <PRI>1 TIMESTAMP HOSTNAME APP-NAME HW_ID MSG_ID - PAYLOAD
%%%
%%% Example (from a real device capture):
%%%
%%%   <31>1 2026-05-22T08:29:50.000Z 1S1R WM-E1S_5.3.59.0 118 0 - BOM2 3
-module(wme_syslog).

-export([format_entry/1, parse_line/1, parse_blob/1,
         category_name/1, message_name/2, split_lines/1]).

-define(DEFAULT_PRI, 31).
-define(DEFAULT_HOSTNAME, <<"1S1P">>).
-define(DEFAULT_APP, <<"WM-E1S_5.3.61.0">>).
-define(DEFAULT_HW_ID, 118).

-type entry() :: #{
          pri := non_neg_integer(),
          version := 1,
          timestamp := binary(),
          hostname := binary(),
          app_name := binary(),
          hw_id := non_neg_integer(),
          message_id := non_neg_integer(),
          payload := binary()
      }.

%% Build one WM-E syslog line (includes trailing CRLF).
-spec format_entry(map()) -> binary().
format_entry(Opts) ->
    Pri = maps:get(pri, Opts, ?DEFAULT_PRI),
    Ts = maps:get(timestamp, Opts, timestamp_now()),
    Host = maps:get(hostname, Opts, ?DEFAULT_HOSTNAME),
    App = maps:get(app_name, Opts, ?DEFAULT_APP),
    HwId = maps:get(hw_id, Opts, ?DEFAULT_HW_ID),
    MsgId = maps:get(message_id, Opts, 0),
    Payload = maps:get(payload, Opts, <<>>),
    iolist_to_binary(
      io_lib:format("<~b>1 ~s ~s ~s ~b ~b - ~s\r\n",
                    [Pri, Ts, Host, App, HwId, MsgId, Payload])).

%% Parse one syslog line. Returns `{error, bad_line}` on mismatch.
-spec parse_line(binary()) -> {ok, entry()} | {error, bad_line}.
parse_line(Line0) ->
    Line = trim_crlf(Line0),
    case re:run(Line,
                "^<([0-9]+)>([0-9]+) ([^ ]+) ([^ ]+) ([^ ]+) ([0-9]+) ([0-9]+) - (.*)$",
                [{capture, all_but_first, binary}]) of
        {match, [PriB, VerB, Ts, Host, App, HwB, MsgB, Payload]} ->
            case {parse_int(PriB), parse_int(VerB), parse_int(HwB), parse_int(MsgB)} of
                {Pri, 1, HwId, MsgId} when is_integer(Pri), is_integer(HwId),
                                           is_integer(MsgId), Pri >= 0 ->
                    {ok, #{pri => Pri, version => 1, timestamp => Ts,
                           hostname => Host, app_name => App,
                           hw_id => HwId, message_id => MsgId,
                           payload => Payload}};
                _ ->
                    {error, bad_line}
            end;
        nomatch ->
            {error, bad_line}
    end.

%% Parse a reassembled WM-E syslog blob into entries (padding/zero lines skipped).
-spec parse_blob(binary()) -> {ok, [entry()]} | {error, term()}.
parse_blob(Blob) when is_binary(Blob) ->
    Entries = lists:filtermap(
      fun(Line) ->
          case parse_line(Line) of
              {ok, E} -> {true, E};
              {error, bad_line} -> false
          end
      end,
      split_lines(Blob)),
    {ok, Entries}.

%% Split blob on newlines, drop empty/all-zero padding lines.
-spec split_lines(binary()) -> [binary()].
split_lines(Blob) ->
    [L || L <- binary:split(Blob, [<<"\n">>, <<"\r\n">>], [global]),
          not is_padding_line(L)].

-spec category_name(non_neg_integer()) -> binary().
category_name(0) -> <<"CATEGORY_DEVICE">>;
category_name(1) -> <<"CATEGORY_FW_UPDATE">>;
category_name(2) -> <<"CATEGORY_AT">>;
category_name(3) -> <<"CATEGORY_GSM">>;
category_name(4) -> <<"CATEGORY_PDP">>;
category_name(5) -> <<"CATEGORY_CSD">>;
category_name(6) -> <<"CATEGORY_SMS">>;
category_name(7) -> <<"CATEGORY_SOCKET">>;
category_name(8) -> <<"CATEGORY_RTC">>;
category_name(9) -> <<"CATEGORY_LASTGASP">>;
category_name(10) -> <<"CATEGORY_EVENT_QUEUE">>;
category_name(11) -> <<"CATEGORY_TRANSPARENT_AT">>;
category_name(12) -> <<"CATEGORY_PUSH_SCHEDULER">>;
category_name(13) -> <<"CATEGORY_PING">>;
category_name(14) -> <<"CATEGORY_NTP">>;
category_name(15) -> <<"CATEGORY_TCP">>;
category_name(16) -> <<"CATEGORY_UDP">>;
category_name(17) -> <<"CATEGORY_FTP">>;
category_name(18) -> <<"CATEGORY_EI">>;
category_name(19) -> <<"CATEGORY_IEC">>;
category_name(20) -> <<"CATEGORY_C86X">>;
category_name(21) -> <<"CATEGORY_WAKEUP">>;
category_name(22) -> <<"CATEGORY_DM">>;
category_name(23) -> <<"CATEGORY_INPUT">>;
category_name(24) -> <<"CATEGORY_CI">>;
category_name(25) -> <<"CATEGORY_SNMP">>;
category_name(26) -> <<"CATEGORY_TLS">>;
category_name(27) -> <<"CATEGORY_INTERFACE">>;
category_name(N) -> iolist_to_binary(io_lib:format("CATEGORY_~b", [N])).

%% Message names for CATEGORY_DEVICE (plans/Syslog.md § CATEGORY_DEVICE).
-spec message_name(0..27, non_neg_integer()) -> binary().
message_name(0, 0) -> <<"MESSAGE_DEVICE_SYSLOG_CLEAR">>;
message_name(0, 1) -> <<"MESSAGE_DEVICE_POWER_UP">>;
message_name(0, 2) -> <<"MESSAGE_DEVICE_FW_RESTART_UPDATE">>;
message_name(0, 3) -> <<"MESSAGE_DEVICE_FW_RESTART_CONFIG">>;
message_name(0, 4) -> <<"MESSAGE_DEVICE_FW_RESTART_SCHEDULE">>;
message_name(0, 5) -> <<"MESSAGE_DEVICE_FW_RESTART_WAKEUP">>;
message_name(0, 6) -> <<"MESSAGE_DEVICE_FW_RESTART_MODEM">>;
message_name(0, 7) -> <<"MESSAGE_DEVICE_ERROR_WDG">>;
message_name(0, 8) -> <<"MESSAGE_DEVICE_ERROR_OVERFLOW">>;
message_name(0, 9) -> <<"MESSAGE_DEVICE_ERROR_CONFIG">>;
message_name(0, 10) -> <<"MESSAGE_DEVICE_ERROR_MODEM">>;
message_name(0, 11) -> <<"MESSAGE_DEVICE_ERROR_INIT">>;
message_name(0, 12) -> <<"MESSAGE_DEVICE_CONFIG_START">>;
message_name(0, 13) -> <<"MESSAGE_DEVICE_CONFIG_END_OK">>;
message_name(0, 14) -> <<"MESSAGE_DEVICE_CONFIG_END_ERROR">>;
message_name(0, 15) -> <<"MESSAGE_DEVICE_CONFIG_OPERATION">>;
message_name(Cat, Id) ->
    iolist_to_binary(
      io_lib:format("~s:~b", [category_name(Cat), Id])).

timestamp_now() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:universal_time(),
    Ms = (erlang:system_time(microsecond) rem 1000000) div 1000,
    iolist_to_binary(
      io_lib:format("~4..0b-~2..0b-~2..0bT~2..0b:~2..0b:~2..0b.~3..0bZ",
                    [Y, Mo, D, H, Mi, S, Ms])).

trim_crlf(Bin) ->
    trim_end(Bin, byte_size(Bin)).

trim_end(Bin, 0) ->
    Bin;
trim_end(Bin, N) ->
    case binary:at(Bin, N - 1) of
        $\r -> trim_end(Bin, N - 1);
        $\n -> trim_end(Bin, N - 1);
        _ -> binary:part(Bin, 0, N)
    end.

is_padding_line(Bin) ->
    Trim = trim_crlf(Bin),
    case Trim of
        <<>> ->
            true;
        _ ->
            lists:all(fun(0) -> true; (_) -> false end, binary_to_list(Trim))
    end.

parse_int(Bin) ->
    try binary_to_integer(Bin) of
        N when N >= 0 -> N
    catch _:_ -> error
    end.
