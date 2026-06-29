%%% @doc Public API facade for the management server.
-module(dmd_mgmt).

-export([load_csv/1, list_devices/0, send_command/2,
         driver_trigger/0, driver_count/0,
         wme_read_config/2]).

%% (Re)load device inventory into the registry from a CSV file.
-spec load_csv(file:name_all()) -> {ok, non_neg_integer()} | {error, term()}.
load_csv(Path) ->
    case dmd_csv:read(Path) of
        {ok, Rows} ->
            [mgmt_registry:register(maps:get(imei, Row), Row#{status => provisioned})
             || Row <- Rows],
            {ok, length(Rows)};
        {error, Reason} ->
            {error, Reason}
    end.

%% Snapshot of every device known to the management server.
-spec list_devices() -> [map()].
list_devices() -> mgmt_registry:all().

%% Send STAT, REBOOT or SECLOG to a device by IMEI.
-spec send_command(binary(), stat | reboot | seclog) ->
          {ok, {binary(), non_neg_integer(), binary()}} | {error, term()}.
send_command(IMEI, Cmd) -> mgmt_commander:send_command(IMEI, Cmd).

%% Fire one autonomous command now.
-spec driver_trigger() -> ok.
driver_trigger() -> mgmt_driver:trigger().

%% Number of autonomous commands issued so far.
-spec driver_count() -> non_neg_integer().
driver_count() -> mgmt_driver:count().

%% Act as a WM-E client (WMETerm): connect to the device's WM-E port and read a
%% config blob. Object is config (16#FF), status (16#0D), meter (16#0B), or a
%% raw option byte.
-spec wme_read_config(binary(), config | status | meter | byte()) ->
          {ok, binary()} | {error, term()}.
wme_read_config(IMEI, Object) ->
    case mgmt_registry:lookup(IMEI) of
        {ok, #{ip := IP, port := Port}} ->
            wme_client:read_config(IP, Port, wme_option(Object), 30000);
        {error, not_found} ->
            {error, device_not_found}
    end.

wme_option(config) -> 16#FF;
wme_option(status) -> 16#0D;
wme_option(meter) -> 16#0B;
wme_option(N) when is_integer(N) -> N.
