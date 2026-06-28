%%% @doc Simulated device, modelled as a gen_statem.
%%%
%%% States:
%%%   running   - normal operation; sends periodic CALLs, answers commands.
%%%   rebooting - after a REBOOT command; CALLs paused and STAT fails (code 1)
%%%               until the reboot duration elapses, then back to running.
%%%
%%% The periodic CALL is the "TCP client" half of the device: each tick it
%%% dials the management server, sends `CALL: IMEI,IP', reads the `CALL:0'
%%% ack and closes.
-module(device_agent).
-behaviour(gen_statem).

-export([start_link/3, handle_command/2, status_line/1]).
-export([init/1, callback_mode/0, terminate/3]).
-export([running/3, rebooting/3]).

-define(FIRST_CALL_DELAY, 500).

start_link(IMEI, IP, Port) ->
    gen_statem:start_link(?MODULE, [IMEI, IP, Port], []).

callback_mode() -> state_functions.

%% Called by the device listener's connection handler. Returns
%% `{Code, Data}' to be encoded into the response.
-spec handle_command(pid(), term()) -> {device_cmd:code(), binary()}.
handle_command(Pid, Cmd) ->
    gen_statem:call(Pid, {command, Cmd}).

%% Build the status payload (also used by device_cmd for STAT).
-spec status_line(map()) -> binary().
status_line(#{imei := IMEI, fw := Fw, config_ver := Cv,
              boot_time := Bt, state := State}) ->
    Uptime = erlang:system_time(second) - Bt,
    iolist_to_binary(
      io_lib:format("imei=~s;state=~s;uptime=~bs;fw=~s;cfg=~b",
                    [IMEI, State, Uptime, Fw, Cv])).

init([IMEI, IP, Port]) ->
    Data = #{imei => IMEI, ip => IP, port => Port,
             fw => <<"1.0.0">>, config_ver => 1,
             boot_time => erlang:system_time(second),
             state => running},
    %% Self-register so the commander can route to us before the first CALL.
    mgmt_registry:register(IMEI, IP, Port, booting),
    {ok, running, Data, [{state_timeout, ?FIRST_CALL_DELAY, send_call}]}.

%%====================================================================
%% running
%%====================================================================

running(state_timeout, send_call, Data) ->
    send_call(Data),
    {keep_state, Data, [{state_timeout, dmd_config:call_interval_ms(), send_call}]};
running({call, From}, {command, Cmd}, Data) ->
    case device_cmd:handle(Cmd, Data) of
        {Code, RespData, reboot} ->
            RebootMs = dmd_config:reboot_duration_ms(),
            Data1 = Data#{state => rebooting},
            mgmt_registry:register(maps:get(imei, Data), maps:get(ip, Data),
                                   maps:get(port, Data), rebooting),
            {next_state, rebooting, Data1,
             [{reply, From, {Code, RespData}},
              {state_timeout, RebootMs, boot_done}]};
        {Code, RespData, none} ->
            {keep_state, Data, [{reply, From, {Code, RespData}}]}
    end;
running(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

%%====================================================================
%% rebooting
%%====================================================================

rebooting(state_timeout, boot_done, Data) ->
    Data1 = Data#{state => running, boot_time => erlang:system_time(second)},
    mgmt_registry:register(maps:get(imei, Data), maps:get(ip, Data),
                           maps:get(port, Data), online),
    {next_state, running, Data1, [{state_timeout, ?FIRST_CALL_DELAY, send_call}]};
rebooting({call, From}, {command, _Cmd}, Data) ->
    %% Device is down: every command fails with code 1 while rebooting.
    {keep_state, Data, [{reply, From, {1, <<"rebooting">>}}]};
rebooting(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

%%====================================================================
%% Shared
%%====================================================================

handle_common({call, From}, _Event, Data) ->
    {keep_state, Data, [{reply, From, {1, <<"unsupported">>}}]};
handle_common(_EventType, _Event, Data) ->
    {keep_state, Data}.

terminate(_Reason, _State, _Data) -> ok.

%% Periodic CALL client: short-lived connect/send/read/close.
send_call(#{imei := IMEI, ip := IP}) ->
    Host = dmd_config:mgmt_host(),
    Port = dmd_config:mgmt_port(),
    case dmd_transport:connect(Host, Port, [], dmd_config:tls_enabled()) of
        {ok, Sock} ->
            _ = dmd_proto:write_msg(Sock, dmd_proto:encode_call(IMEI, IP)),
            _ = dmd_proto:read_msg(Sock, 5000),
            dmd_transport:close(Sock);
        {error, _Reason} ->
            %% Server may be down; just try again next tick.
            ok
    end.
