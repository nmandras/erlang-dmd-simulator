%%% @doc Issues server-initiated commands (STAT/REBOOT) to a device.
%%%
%%% Looks the device up in the registry, dials its IP:port, writes the command
%%% and reads the framed `CMD:code[,data]' response.
-module(mgmt_commander).
-behaviour(gen_server).

-export([start_link/0, send_command/2, send_async/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(RECV_TIMEOUT, 5000).
-define(DOMAIN, #{domain => [dmd, mgmt]}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Synchronous send: dial the device, send the command, return its response.
-spec send_command(binary(), stat | reboot | seclog) ->
          {ok, {binary(), non_neg_integer(), binary()}} | {error, term()}.
send_command(IMEI, Cmd) when Cmd =:= stat; Cmd =:= reboot; Cmd =:= seclog ->
    gen_server:call(?MODULE, {send, IMEI, Cmd}, 15000).

%% Fire-and-forget send, run in its own process so it never blocks the caller
%% (or the commander). `Reason' is a short tag included in the trace log, e.g.
%% the event that triggered the command.
-spec send_async(binary(), stat | reboot | seclog, atom()) -> ok.
send_async(IMEI, Cmd, Reason) when Cmd =:= stat; Cmd =:= reboot; Cmd =:= seclog ->
    gen_server:cast(?MODULE, {send_async, IMEI, Cmd, Reason}).

init([]) -> {ok, #{}}.

handle_call({send, IMEI, Cmd}, _From, S) ->
    {reply, do_send(IMEI, Cmd), S};
handle_call(_Req, _From, S) ->
    {reply, {error, unknown_request}, S}.

handle_cast({send_async, IMEI, Cmd, Reason}, S) ->
    spawn(fun() ->
        Result = do_send(IMEI, Cmd),
        logger:info("CMD send cmd=~s imei=~s reason=~s result=~p",
                    [Cmd, IMEI, Reason, summarise(Result)], ?DOMAIN),
        maybe_chain_seclog(IMEI, Cmd, Result)
    end),
    {noreply, S};
handle_cast(_Msg, S) -> {noreply, S}.

%% A STAT response carrying "SECSTAT:1" means the device has security events
%% pending, so follow up immediately with a SECLOG to fetch them.
maybe_chain_seclog(IMEI, stat, {ok, {<<"STAT">>, _Code, Body}}) ->
    case binary:match(Body, <<"SECSTAT:1">>) of
        nomatch ->
            ok;
        _ ->
            dmd_metrics:incr(dmd_mgmt, seclog_triggered),
            Result = do_send(IMEI, seclog),
            logger:info("CMD send cmd=seclog imei=~s reason=secstat result=~p",
                        [IMEI, summarise(Result)], ?DOMAIN)
    end;
maybe_chain_seclog(_IMEI, _Cmd, _Result) ->
    ok.
handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.

summarise({ok, {Name, Code, _Data}}) -> {Name, Code};
summarise(Other) -> Other.

do_send(IMEI, Cmd) ->
    case mgmt_registry:lookup(IMEI) of
        {ok, #{ip := IP, port := Port}} ->
            connect_and_send(IP, Port, Cmd);
        {error, not_found} ->
            {error, device_not_found}
    end.

connect_and_send(IP, Port, Cmd) ->
    dmd_conn_limit:with(dmd_mgmt, fun() -> connect_and_send1(IP, Port, Cmd) end).

connect_and_send1(IP, Port, Cmd) ->
    case dmd_transport:connect(IP, Port, [], dmd_config:connect_tls(dmd_mgmt)) of
        {ok, Sock} ->
            Result = exchange(Sock, Cmd),
            dmd_transport:close(Sock),
            Result;
        {error, Reason} ->
            {error, {connect_failed, Reason}}
    end.

exchange(Sock, Cmd) ->
    case dmd_proto:write_msg(Sock, dmd_proto:encode_command(Cmd)) of
        ok ->
            case dmd_proto:read_msg(Sock, ?RECV_TIMEOUT) of
                {ok, Resp} -> {ok, dmd_proto:decode_response(Resp)};
                {error, R} -> {error, R}
            end;
        {error, R} ->
            {error, R}
    end.
