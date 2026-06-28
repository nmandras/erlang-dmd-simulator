%%% @doc Issues server-initiated commands (STAT/REBOOT) to a device.
%%%
%%% Looks the device up in the registry, dials its IP:port, writes the command
%%% and reads the framed `CMD:code[,data]' response.
-module(mgmt_commander).
-behaviour(gen_server).

-export([start_link/0, send_command/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(RECV_TIMEOUT, 5000).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec send_command(binary(), stat | reboot) ->
          {ok, {binary(), non_neg_integer(), binary()}} | {error, term()}.
send_command(IMEI, Cmd) when Cmd =:= stat; Cmd =:= reboot ->
    gen_server:call(?MODULE, {send, IMEI, Cmd}, 15000).

init([]) -> {ok, #{}}.

handle_call({send, IMEI, Cmd}, _From, S) ->
    {reply, do_send(IMEI, Cmd), S};
handle_call(_Req, _From, S) ->
    {reply, {error, unknown_request}, S}.

handle_cast(_Msg, S) -> {noreply, S}.
handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.

do_send(IMEI, Cmd) ->
    case mgmt_registry:lookup(IMEI) of
        {ok, #{ip := IP, port := Port}} ->
            connect_and_send(IP, Port, Cmd);
        {error, not_found} ->
            {error, device_not_found}
    end.

connect_and_send(IP, Port, Cmd) ->
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
