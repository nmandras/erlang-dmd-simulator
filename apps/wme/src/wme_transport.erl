%%% @doc Minimal TCP transport for WM-E. Handshake lines use {packet, line};
%%% binary frames are read with exact lengths after switching to {packet, raw}.
-module(wme_transport).

-export([listen/2, accept/1, connect/3,
         send/2, recv_line/2, recv_exact/3,
         set_raw/1, controlling_process/2, close/1]).

-spec listen(inet:port_number(), inet:ip_address()) ->
          {ok, gen_tcp:socket()} | {error, term()}.
listen(Port, IP) ->
    gen_tcp:listen(Port, [binary, {packet, line}, {active, false},
                          {reuseaddr, true}, {backlog, 1024}, {ip, IP}]).

accept(LSock) -> gen_tcp:accept(LSock).

-spec connect(inet:socket_address(), inet:port_number(), timeout()) ->
          {ok, gen_tcp:socket()} | {error, term()}.
connect(Host, Port, Timeout) ->
    gen_tcp:connect(Host, Port, [binary, {packet, line}, {active, false}], Timeout).

send(Sock, Data) -> gen_tcp:send(Sock, Data).

%% One newline-delimited line (used during IEC handshake).
recv_line(Sock, Timeout) -> gen_tcp:recv(Sock, 0, Timeout).

%% Exactly N bytes (used for binary frames after set_raw/1).
recv_exact(Sock, N, Timeout) -> gen_tcp:recv(Sock, N, Timeout).

set_raw(Sock) -> inet:setopts(Sock, [{packet, raw}]).

controlling_process(Sock, Pid) -> gen_tcp:controlling_process(Sock, Pid).

close(Sock) -> gen_tcp:close(Sock).
