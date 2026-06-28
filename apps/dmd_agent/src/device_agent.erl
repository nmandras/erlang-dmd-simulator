%%% @doc Simulated device, modelled as a gen_statem.
%%%
%%% States:
%%%   running   - normal operation; sends periodic CALLs, answers commands.
%%%   rebooting - after a REBOOT command; CALLs paused and commands fail
%%%               (code 1) until the reboot duration elapses, then running.
%%%
%%% The periodic CALL is the "TCP client" half of the device: each tick it
%%% dials the management server, sends `CALL: IMEI,IP', reads the ack and
%%% logs the result (timestamped via logger).
-module(device_agent).
-behaviour(gen_statem).

-export([start_link/4, handle_command/2, status_line/1]).
-export([init/1, callback_mode/0, terminate/3]).
-export([running/3, rebooting/3]).

-define(FIRST_CALL_DELAY, 500).
-define(DOMAIN, #{domain => [dmd, agent]}).

start_link(IMEI, IP, Port, PeriodMs) ->
    gen_statem:start_link(?MODULE, [IMEI, IP, Port, PeriodMs], []).

callback_mode() -> state_functions.

-spec handle_command(pid(), term()) -> {device_cmd:code(), binary()}.
handle_command(Pid, Cmd) ->
    gen_statem:call(Pid, {command, Cmd}).

-spec status_line(map()) -> binary().
status_line(#{imei := IMEI, fw := Fw, config_ver := Cv,
              boot_time := Bt, state := State}) ->
    Uptime = erlang:system_time(second) - Bt,
    iolist_to_binary(
      io_lib:format("imei=~s;state=~s;uptime=~bs;fw=~s;cfg=~b",
                    [IMEI, State, Uptime, Fw, Cv])).

init([IMEI, IP, Port, PeriodMs]) ->
    Data = #{imei => IMEI, ip => IP, port => Port, period_ms => PeriodMs,
             fw => <<"1.0.0">>, config_ver => 1,
             boot_time => erlang:system_time(second),
             state => running},
    {ok, running, Data, [{state_timeout, ?FIRST_CALL_DELAY, send_call}]}.

%%====================================================================
%% running
%%====================================================================

running(state_timeout, send_call, Data) ->
    send_call(Data),
    {keep_state, Data, [{state_timeout, maps:get(period_ms, Data), send_call}]};
running({call, From}, {command, Cmd}, Data) ->
    {Code, RespData, Action} = device_cmd:handle(Cmd, Data),
    log_command(Data, Cmd, Code),
    case Action of
        reboot ->
            RebootMs = dmd_config:get(dmd_agent, reboot_duration_ms, 5000),
            logger:info("REBOOT imei=~s for ~bms",
                        [maps:get(imei, Data), RebootMs], ?DOMAIN),
            {next_state, rebooting, Data#{state => rebooting},
             [{reply, From, {Code, RespData}},
              {state_timeout, RebootMs, boot_done}]};
        none ->
            {keep_state, Data, [{reply, From, {Code, RespData}}]}
    end;
running(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

%%====================================================================
%% rebooting
%%====================================================================

rebooting(state_timeout, boot_done, Data) ->
    logger:info("BOOT imei=~s back online", [maps:get(imei, Data)], ?DOMAIN),
    Data1 = Data#{state => running, boot_time => erlang:system_time(second)},
    {next_state, running, Data1, [{state_timeout, ?FIRST_CALL_DELAY, send_call}]};
rebooting({call, From}, {command, Cmd}, Data) ->
    log_command(Data, Cmd, 1),
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

%% Periodic CALL client: short-lived connect/send/read/close, then log.
send_call(#{imei := IMEI, ip := IP}) ->
    Host = dmd_config:mgmt_host(dmd_agent),
    Port = dmd_config:mgmt_port(dmd_agent),
    T0 = erlang:monotonic_time(millisecond),
    Result = do_call(IMEI, IP, Host, Port),
    Dt = erlang:monotonic_time(millisecond) - T0,
    record_call(Result, Dt),
    logger:info("CALL imei=~s ip=~s -> ~s:~b result=~p",
                [IMEI, dmd_proto:ip_to_bin(IP),
                 dmd_proto:ip_to_bin(Host), Port, Result],
                ?DOMAIN).

record_call({<<"CALL">>, 0, _}, Dt) ->
    dmd_metrics:incr(dmd_agent, calls_sent_ok),
    dmd_metrics:observe(dmd_agent, call_latency_ms, Dt);
record_call(_Other, _Dt) ->
    dmd_metrics:incr(dmd_agent, calls_sent_failed).

do_call(IMEI, IP, Host, Port) ->
    case dmd_transport:connect(Host, Port, [], dmd_config:connect_tls(dmd_agent)) of
        {ok, Sock} ->
            R = case dmd_proto:write_msg(Sock, dmd_proto:encode_call(IMEI, IP)) of
                    ok ->
                        case dmd_proto:read_msg(Sock, 5000) of
                            {ok, Resp} -> dmd_proto:decode_response(Resp);
                            Err -> Err
                        end;
                    Err -> Err
                end,
            dmd_transport:close(Sock),
            R;
        {error, Reason} ->
            {error, Reason}
    end.

log_command(#{imei := IMEI}, Cmd, Code) ->
    dmd_metrics:incr(dmd_agent, commands_received),
    logger:info("CMD recv imei=~s cmd=~p code=~b", [IMEI, Cmd, Code], ?DOMAIN).
