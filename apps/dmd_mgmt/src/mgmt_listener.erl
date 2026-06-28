%%% @doc Management server CALL-ingestion listener.
%%%
%%% Owns the listening socket and a linked acceptor. Each accepted connection
%%% reads one framed CALL, logs it (timestamped), refreshes the registry and
%%% replies `CALL:0' (or `ERR:1' on a bad request).
-module(mgmt_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(RECV_TIMEOUT, 5000).
-define(DOMAIN, #{domain => [dmd, mgmt]}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    process_flag(trap_exit, true),
    Port = dmd_config:mgmt_port(dmd_mgmt),
    ExtraOpts = [{ip, dmd_config:mgmt_host(dmd_mgmt)}],
    {ok, LSock} = dmd_transport:listen(Port, ExtraOpts, dmd_config:listen_tls(dmd_mgmt)),
    logger:info("management server listening on port ~b", [Port], ?DOMAIN),
    Acceptor = spawn_acceptor(LSock),
    {ok, #{lsock => LSock, acceptor => Acceptor}}.

handle_call(_Req, _From, S) -> {reply, ok, S}.
handle_cast(_Msg, S) -> {noreply, S}.

handle_info({'EXIT', Pid, _Reason}, S = #{acceptor := Pid, lsock := LSock}) ->
    {noreply, S#{acceptor => spawn_acceptor(LSock)}};
handle_info(_Info, S) -> {noreply, S}.

terminate(_Reason, #{lsock := LSock}) ->
    dmd_transport:close(LSock),
    ok.

%%====================================================================
%% Acceptor / connection handling
%%====================================================================

spawn_acceptor(LSock) ->
    spawn_link(fun() -> accept_loop(LSock) end).

accept_loop(LSock) ->
    case dmd_transport:accept(LSock) of
        {ok, Sock} ->
            Pid = spawn(fun() -> receive go -> handle_conn(Sock) end end),
            case dmd_transport:controlling_process(Sock, Pid) of
                ok -> Pid ! go;
                _ -> dmd_transport:close(Sock)
            end,
            accept_loop(LSock);
        {error, closed} ->
            ok;
        {error, _Other} ->
            accept_loop(LSock)
    end.

handle_conn(Sock) ->
    case dmd_proto:read_msg(Sock, ?RECV_TIMEOUT) of
        {ok, Payload} ->
            Resp = case dmd_proto:decode_request(Payload) of
                       {call, IMEI, IP} ->
                           logger:info("CALL recv imei=~s ip=~s", [IMEI, IP], ?DOMAIN),
                           mgmt_registry:touch(IMEI, IP, online),
                           dmd_proto:encode_response(call, 0);
                       _ ->
                           logger:warning("bad request: ~p", [Payload], ?DOMAIN),
                           dmd_proto:encode_response(<<"ERR">>, 1)
                   end,
            _ = dmd_proto:write_msg(Sock, Resp);
        {error, _} ->
            ok
    end,
    dmd_transport:close(Sock).
