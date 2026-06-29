%%% @doc Per-device WM-E listener: binds the device's IP on the WM-E config port
%%% and serves config-read sessions (the device is the WM-E server). Mirrors the
%%% device_listener acceptor pattern but speaks the WM-E protocol.
-module(device_wme_listener).
-behaviour(gen_server).

-export([start_link/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SESSION_TIMEOUT, 30000).

start_link(IMEI, IP) ->
    gen_server:start_link(?MODULE, [IMEI, IP], []).

init([IMEI, IP]) ->
    process_flag(trap_exit, true),
    Port = dmd_config:get(dmd_agent, wme_port, 9998),
    {ok, LSock} = wme_transport:listen(Port, IP),
    {ok, #{lsock => LSock, acceptor => spawn_acceptor(LSock, IMEI), imei => IMEI}}.

handle_call(_Req, _From, S) -> {reply, ok, S}.
handle_cast(_Msg, S) -> {noreply, S}.

handle_info({'EXIT', Pid, _Reason}, S = #{acceptor := Pid, lsock := LSock, imei := IMEI}) ->
    {noreply, S#{acceptor => spawn_acceptor(LSock, IMEI)}};
handle_info(_Info, S) -> {noreply, S}.

terminate(_Reason, #{lsock := LSock}) ->
    wme_transport:close(LSock),
    ok.

%%====================================================================
%% Acceptor
%%====================================================================

spawn_acceptor(LSock, IMEI) ->
    spawn_link(fun() -> accept_loop(LSock, IMEI) end).

accept_loop(LSock, IMEI) ->
    case wme_transport:accept(LSock) of
        {ok, Sock} ->
            Ident = dmd_config:get(dmd_agent, wme_ident, device_wme:ident(IMEI)),
            Provider = fun(Option) -> device_wme:config_blob(IMEI, Option) end,
            Pid = spawn(fun() ->
                receive go ->
                    wme_sim_device:serve(Sock, Ident, 256, Provider, ?SESSION_TIMEOUT)
                end
            end),
            case wme_transport:controlling_process(Sock, Pid) of
                ok -> Pid ! go;
                _ -> wme_transport:close(Sock)
            end,
            accept_loop(LSock, IMEI);
        {error, closed} ->
            ok;
        {error, _Other} ->
            accept_loop(LSock, IMEI)
    end.
