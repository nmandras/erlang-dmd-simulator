%%% @doc Per-device WM-E config content. Generates a deterministic config blob
%%% (and status blob) from the device IMEI, used by the WM-E simulator listener.
-module(device_wme).

-export([config_blob/2, ident/1]).

%% Provider for wme_sim_device: option byte -> blob.
-spec config_blob(binary(), byte()) -> {ok, binary()} | error.
config_blob(IMEI, 16#FF) -> {ok, full_config(IMEI)};
config_blob(IMEI, 16#0D) -> {ok, status_blob(IMEI)};
config_blob(_IMEI, _Other) -> error.

%% IEC ident line for this device (V1 chunking; no "1K"/"1024" marker).
-spec ident(binary()) -> binary().
ident(_IMEI) ->
    <<"/ELS5\\3 5.3.59.0 118\r\n">>.

%% ~700-byte deterministic config so reads span several V1 (256-byte) packets.
full_config(IMEI) ->
    Base = binary_to_integer(IMEI),
    Header = <<"WME-CONFIG imei=", IMEI/binary, "\n">>,
    Body = iolist_to_binary(
             [io_lib:format("param~3..0b=~b\n", [N, (Base + N) rem 100000])
              || N <- lists:seq(1, 60)]),
    <<Header/binary, Body/binary>>.

status_blob(IMEI) ->
    iolist_to_binary(["WME-STATUS imei=", IMEI, " state=online\n"]).
