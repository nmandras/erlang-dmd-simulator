%%% @doc Public API facade for the management server.
-module(dmd_mgmt).

-export([load_csv/1, list_devices/0, send_command/2,
         driver_trigger/0, driver_count/0]).

%% (Re)load device inventory into the registry from a CSV file.
-spec load_csv(file:name_all()) -> {ok, non_neg_integer()} | {error, term()}.
load_csv(Path) ->
    case dmd_csv:read(Path) of
        {ok, Rows} ->
            [mgmt_registry:register(Imei, IP, Port, provisioned)
             || #{imei := Imei, ip := IP, port := Port} <- Rows],
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
