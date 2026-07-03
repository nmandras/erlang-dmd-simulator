%%% @doc Wire protocol: framing, encoding and decoding.
%%%
%%% Framing: every message on the wire is `<<Len:16/little, Payload:Len/binary>>'
%%% — the first two bytes give the payload length, least-significant byte first.
%%%
%%% Requests (payload):
%%%   `CALL:<15-digit-IMEI>,<ip>'              agent -> server, periodic status
%%%   `CALL:<15-digit-IMEI>,<ip>\n<stat-body>'  optional inline status (WME)
%%%   `STAT'                          server -> agent, ask for status
%%%   `REBOOT'                        server -> agent, reboot
%%%
%%% Responses (payload): every request is answered by the peer with the
%%% command name, a result code (`0' success, `1' failure) and optional data:
%%%   `CALL:0'  `REBOOT:0'  `STAT:0,imei=...;state=...'  `STAT:1,rebooting'
-module(dmd_proto).

-export([frame/1, write_msg/2, read_msg/2]).
-export([encode_call/2, encode_call/3, encode_command/1, decode_request/1,
         encode_response/2, encode_response/3, decode_response/1, command_tag/1]).
-export([valid_imei/1, ip_to_bin/1]).

-define(LEN_BYTES, 2).
-define(MAX_PAYLOAD, 65535).

-define(FAIL, 1).

%%====================================================================
%% Framing
%%====================================================================

-spec frame(binary()) -> binary().
frame(Payload) when is_binary(Payload), byte_size(Payload) =< ?MAX_PAYLOAD ->
    <<(byte_size(Payload)):16/little, Payload/binary>>.

-spec write_msg(dmd_transport:socket(), iodata()) -> ok | {error, term()}.
write_msg(Transport, Payload) ->
    dmd_transport:send(Transport, frame(iolist_to_binary(Payload))).

-spec read_msg(dmd_transport:socket(), timeout()) ->
          {ok, binary()} | {error, term()}.
read_msg(Transport, Timeout) ->
    case dmd_transport:recv(Transport, ?LEN_BYTES, Timeout) of
        {ok, <<0:16/little>>} -> {ok, <<>>};
        {ok, <<Len:16/little>>} -> dmd_transport:recv(Transport, Len, Timeout);
        {error, R} -> {error, R}
    end.

%%====================================================================
%% Requests
%%====================================================================

-spec encode_call(binary(), term()) -> binary().
encode_call(IMEI, IP) ->
    encode_call(IMEI, IP, <<>>).

%% Stat body (when non-empty) is appended after a newline so commas inside
%% status lines do not break IMEI/IP parsing.
-spec encode_call(binary(), term(), binary()) -> binary().
encode_call(IMEI, IP, <<>>) when is_binary(IMEI) ->
    <<"CALL:", IMEI/binary, ",", (ip_to_bin(IP))/binary>>;
encode_call(IMEI, IP, Stat) when is_binary(IMEI), is_binary(Stat) ->
    <<"CALL:", IMEI/binary, ",", (ip_to_bin(IP))/binary, "\n", Stat/binary>>.

-spec encode_command(stat | reboot | seclog) -> binary().
encode_command(stat) -> <<"STAT">>;
encode_command(reboot) -> <<"REBOOT">>;
encode_command(seclog) -> <<"SECLOG">>.

-spec decode_request(binary()) ->
          {call, binary(), binary(), binary()}
        | {command, stat | reboot | {unknown, binary()}}
        | {error, term()}.
decode_request(<<"CALL:", Rest/binary>>) ->
    case binary:split(Rest, <<"\n">>, []) of
        [Head] ->
            parse_call_head(Head, <<>>);
        [Head | Tail] ->
            parse_call_head(Head, iolist_to_binary(lists:join(<<"\n">>, Tail)))
    end;
decode_request(<<"STAT">>) -> {command, stat};
decode_request(<<"REBOOT">>) -> {command, reboot};
decode_request(<<"SECLOG">>) -> {command, seclog};
decode_request(Other) -> {command, {unknown, Other}}.

%%====================================================================
%% Responses
%%====================================================================

-spec encode_response(term(), non_neg_integer()) -> binary().
encode_response(Cmd, Code) when is_integer(Code) ->
    <<(cmd_name(Cmd))/binary, ":", (integer_to_binary(Code))/binary>>.

-spec encode_response(term(), non_neg_integer(), binary()) -> binary().
encode_response(Cmd, Code, <<>>) ->
    encode_response(Cmd, Code);
encode_response(Cmd, Code, Data) when is_binary(Data) ->
    <<(cmd_name(Cmd))/binary, ":", (integer_to_binary(Code))/binary, ",", Data/binary>>.

%% Two shapes are accepted after the command tag:
%%   `CMD:<int>[,<data>]'  -> {Tag, Code, Data}     (CALL:0, REBOOT:0, STAT:1,..)
%%   `CMD:<non-int...>'    -> {Tag, 0, <whole rest>} (rich STAT body, code implied 0)
-spec decode_response(binary()) ->
          {binary(), non_neg_integer(), binary()} | {error, term()}.
decode_response(Bin) ->
    case binary:split(Bin, <<":">>) of
        [Name, Rest] ->
            {Head, Tail} = case binary:split(Rest, <<",">>) of
                               [H, T] -> {H, T};
                               [H] -> {H, <<>>}
                           end,
            case int_opt(Head) of
                {ok, Code} -> {Name, Code, Tail};
                error -> {Name, 0, Rest}
            end;
        _ -> {error, malformed_response}
    end.

%% Response/section tag for a decoded command.
-spec command_tag(term()) -> binary().
command_tag(Cmd) -> cmd_name(Cmd).

%%====================================================================
%% Helpers
%%====================================================================

%% 15 ASCII digits exactly.
-spec valid_imei(term()) -> boolean().
valid_imei(B) when is_binary(B), byte_size(B) =:= 15 ->
    lists:all(fun(C) -> C >= $0 andalso C =< $9 end, binary_to_list(B));
valid_imei(_) -> false.

-spec ip_to_bin(term()) -> binary().
ip_to_bin(B) when is_binary(B) -> B;
ip_to_bin(L) when is_list(L) -> list_to_binary(L);
ip_to_bin({A,B,C,D}) ->
    iolist_to_binary(io_lib:format("~b.~b.~b.~b", [A,B,C,D])).

cmd_name(call) -> <<"CALL">>;
cmd_name(stat) -> <<"STAT">>;
cmd_name(reboot) -> <<"REBOOT">>;
cmd_name(seclog) -> <<"SECLOG">>;
cmd_name({config, _}) -> <<"CONFIG">>;
cmd_name({firmware, _}) -> <<"FIRMWARE">>;
cmd_name({unknown, _}) -> <<"ERR">>;
cmd_name(Bin) when is_binary(Bin) -> Bin.

parse_call_head(Head, Stat) ->
    case binary:split(Head, <<",">>) of
        [IMEI, IP] -> {call, IMEI, IP, Stat};
        _ -> {error, malformed_call}
    end.

int_opt(Bin) ->
    try {ok, binary_to_integer(Bin)} catch _:_ -> error end.
