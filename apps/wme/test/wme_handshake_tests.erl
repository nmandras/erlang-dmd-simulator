%%% @doc IEC handshake tests.
-module(wme_handshake_tests).

-include_lib("eunit/include/eunit.hrl").
-include("wme_constants.hrl").

server_echoes_full_ack_test() ->
    {ok, LSock} = wme_transport:listen(0, {127, 0, 0, 1}),
    {ok, Port} = inet:port(LSock),
    Ident = <<"/ELS5\\7 V5.3.61.0 1S1P\r\n">>,
    Parent = self(),
    Server = spawn(fun() ->
        {ok, Sock} = wme_transport:accept(LSock),
        ok = wme_handshake:server(Sock, Ident, 1000),
        wme_transport:close(Sock),
        Parent ! server_done
    end),
    try
        {ok, CSock} = wme_transport:connect({127, 0, 0, 1}, Port, 1000),
        try
            ok = wme_transport:send(CSock, ?IEC_PROBE),
            ?assertEqual({ok, Ident}, wme_transport:recv_line(CSock, 1000)),
            ok = wme_transport:send(CSock, ?IEC_ACK),
            {ok, Ack} = wme_transport:recv_line(CSock, 1000),
            ?assertEqual(16#06, binary:first(Ack)),
            ?assertNotEqual(nomatch, binary:match(Ack, <<"059">>))
        after
            wme_transport:close(CSock)
        end,
        receive server_done -> ok after 1000 -> error(server_timeout) end
    after
        exit(Server, kill),
        wme_transport:close(LSock)
    end.
