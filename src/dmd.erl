%%% @doc Public API facade for the device management simulator.
%%%
%%% Typical session in `rebar3 shell':
%%% ```
%%% dmd:start_fleet(3).            %% spawn 3 devices on 127.0.0.2..4:6000
%%% dmd:list_devices().           %% fleet snapshot from the server registry
%%% [I|_] = [maps:get(imei,D) || D <- dmd:list_devices()],
%%% dmd:send_command(I, stat).    %% {ok, {<<"STAT">>, 0, <<"imei=...">>}}
%%% dmd:send_command(I, reboot).  %% {ok, {<<"REBOOT">>, 0, <<>>}}
%%% '''
-module(dmd).

-export([start/0, stop/0,
         start_device/1, start_device/3, start_fleet/1,
         stop_device/1, list_devices/0, send_command/2]).

-spec start() -> {ok, [atom()]} | {error, term()}.
start() -> application:ensure_all_started(dmd).

-spec stop() -> ok | {error, term()}.
stop() -> application:stop(dmd).

%% Start one device with an auto-allocated loopback IP and the shared port.
-spec start_device(binary()) -> {ok, pid()} | {error, term()}.
start_device(IMEI) ->
    N = dmd_config:device_ip_first_octet() + device_sup:count(),
    start_device(IMEI, dmd_config:device_ip(N), dmd_config:device_port()).

-spec start_device(binary(), inet:ip_address(), inet:port_number()) ->
          {ok, pid()} | {error, term()}.
start_device(IMEI, IP, Port) when is_binary(IMEI) ->
    case dmd_proto:valid_imei(IMEI) of
        true -> device_sup:start_device(IMEI, IP, Port);
        false -> {error, invalid_imei}
    end.

%% Start `Count' devices with generated IMEIs and distinct loopback IPs.
-spec start_fleet(pos_integer()) -> [binary()].
start_fleet(Count) when is_integer(Count), Count > 0 ->
    First = dmd_config:device_ip_first_octet(),
    Port = dmd_config:device_port(),
    [begin
        IMEI = gen_imei(I),
        {ok, _} = start_device(IMEI, dmd_config:device_ip(First + I), Port),
        IMEI
     end || I <- lists:seq(0, Count - 1)].

-spec stop_device(binary()) -> ok | {error, term()}.
stop_device(IMEI) -> device_sup:stop_device(IMEI).

%% Snapshot of every device known to the management server.
-spec list_devices() -> [map()].
list_devices() -> mgmt_registry:all().

%% Send STAT or REBOOT to a device by IMEI via the management server.
-spec send_command(binary(), stat | reboot) ->
          {ok, {binary(), non_neg_integer(), binary()}} | {error, term()}.
send_command(IMEI, Cmd) -> mgmt_commander:send_command(IMEI, Cmd).

%% 15-digit IMEI: 1 followed by a zero-padded index keeps the width fixed.
gen_imei(I) ->
    integer_to_binary(100000000000000 + I).
