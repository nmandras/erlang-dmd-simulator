%%% @doc Public API facade for the device agent fleet.
-module(dmd_agent).

-export([start_from_csv/1, start_device/4, stop_device/1, count/0]).

%% Start one device per CSV row. Returns the list of started IMEIs.
-spec start_from_csv(file:name_all()) -> {ok, [binary()]} | {error, term()}.
start_from_csv(Path) ->
    case dmd_csv:read(Path) of
        {ok, Rows} ->
            Started =
                [Imei ||
                    #{imei := Imei, ip := IP, port := Port,
                      callperiod_ms := PeriodMs} <- Rows,
                    valid_start(start_device(Imei, IP, Port, PeriodMs))],
            {ok, Started};
        {error, Reason} ->
            {error, Reason}
    end.

-spec start_device(binary(), inet:ip_address(), inet:port_number(),
                   non_neg_integer()) -> {ok, pid()} | {error, term()}.
start_device(IMEI, IP, Port, PeriodMs) when is_binary(IMEI) ->
    case dmd_proto:valid_imei(IMEI) of
        true -> device_sup:start_device(IMEI, IP, Port, PeriodMs);
        false -> {error, invalid_imei}
    end.

-spec stop_device(binary()) -> ok | {error, term()}.
stop_device(IMEI) -> device_sup:stop_device(IMEI).

-spec count() -> non_neg_integer().
count() -> device_sup:count().

valid_start({ok, _Pid}) -> true;
valid_start(_Other) -> false.
