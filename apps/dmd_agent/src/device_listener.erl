%%% @doc Device inbound listener — the "TCP server" half of a device.
%%%
%%% Owns a listening socket bound to the device's own IP:port and a linked
%%% acceptor. Each accepted connection reads one framed command, dispatches it
%%% to the device's agent, and writes the `CMD:code[,data]' response.
-module(device_listener).
-behaviour(gen_server).

-export([start_link/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(RECV_TIMEOUT, 5000).

start_link(Sup, IMEI, IP, Port) ->
    gen_server:start_link(?MODULE, [Sup, IMEI, IP, Port], []).

init([Sup, IMEI, IP, Port]) ->
    process_flag(trap_exit, true),
    ExtraOpts = [{ip, IP}],
    {ok, LSock} = dmd_transport:listen(Port, ExtraOpts, dmd_config:listen_tls(dmd_agent)),
    Acceptor = spawn_acceptor(LSock, Sup),
    {ok, #{lsock => LSock, acceptor => Acceptor, sup => Sup, imei => IMEI}}.

handle_call(_Req, _From, S) -> {reply, ok, S}.
handle_cast(_Msg, S) -> {noreply, S}.

handle_info({'EXIT', Pid, _Reason}, S = #{acceptor := Pid, lsock := LSock, sup := Sup}) ->
    {noreply, S#{acceptor => spawn_acceptor(LSock, Sup)}};
handle_info(_Info, S) -> {noreply, S}.

terminate(_Reason, #{lsock := LSock}) ->
    dmd_transport:close(LSock),
    ok.

%%====================================================================
%% Acceptor / connection handling
%%====================================================================

spawn_acceptor(LSock, Sup) ->
    spawn_link(fun() -> accept_loop(LSock, Sup) end).

accept_loop(LSock, Sup) ->
    case dmd_transport:accept(LSock) of
        {ok, Sock} ->
            Pid = spawn(fun() -> receive go -> handle_conn(Sock, Sup) end end),
            case dmd_transport:controlling_process(Sock, Pid) of
                ok -> Pid ! go;
                _ -> dmd_transport:close(Sock)
            end,
            accept_loop(LSock, Sup);
        {error, closed} ->
            ok;
        {error, _Other} ->
            accept_loop(LSock, Sup)
    end.

handle_conn(Sock, Sup) ->
    case dmd_proto:read_msg(Sock, ?RECV_TIMEOUT) of
        {ok, Payload} ->
            Cmd = to_command(dmd_proto:decode_request(Payload)),
            {_Code, Resp} = dispatch(Sup, Cmd),
            _ = dmd_proto:write_msg(Sock, Resp);
        {error, _} ->
            ok
    end,
    dmd_transport:close(Sock).

%% A device only ever receives commands; a stray CALL is treated as unknown.
to_command({command, Cmd}) -> Cmd;
to_command({call, _, _}) -> {unknown, <<"CALL">>};
to_command({error, _}) -> {unknown, <<>>}.

%% Returns {Code, Payload}; the handlers build the full response bytes.
dispatch(Sup, Cmd) ->
    case device_instance_sup:agent_pid(Sup) of
        undefined ->
            {1, dmd_proto:encode_response(<<"ERR">>, 1, <<"no-agent">>)};
        Pid ->
            try device_agent:handle_command(Pid, Cmd) of
                {Code, Payload} -> {Code, Payload}
            catch
                _:_ -> {1, dmd_proto:encode_response(<<"ERR">>, 1, <<"error">>)}
            end
    end.
