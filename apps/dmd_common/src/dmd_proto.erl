%%% @doc Wire protocol: framing, encoding and decoding.
%%%
%%% Framing: every message on the wire is `<<Len:16/little, Payload:Len/binary>>'
%%% — the first two bytes give the payload length, least-significant byte first.
%%%
%%% Requests (payload):
%%%   `CALL: <15-digit-IMEI>,<ip>'   agent -> server, periodic status
%%%   `STAT'                          server -> agent, ask for status
%%%   `REBOOT'                        server -> agent, reboot
%%%
%%% Responses (payload): every request is answered by the peer with the
%%% command name, a result code (`0' success, `1' failure) and optional data:
%%%   `CALL:0'  `REBOOT:0'  `STAT:0,imei=...;state=...'  `STAT:1,rebooting'
-module(dmd_proto).

-export([frame/1, write_msg/2, read_msg/2]).
-export([encode_call/2, encode_command/1, decode_request/1,
         encode_response/2, encode_response/3, decode_response/1]).
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
encode_call(IMEI, IP) when is_binary(IMEI) ->
    <<"CALL: ", IMEI/binary, ",", (ip_to_bin(IP))/binary>>.

-spec encode_command(stat | reboot) -> binary().
encode_command(stat) -> <<"STAT">>;
encode_command(reboot) -> <<"REBOOT">>.

-spec decode_request(binary()) ->
          {call, binary(), binary()}
        | {command, stat | reboot | {unknown, binary()}}
        | {error, term()}.
decode_request(<<"CALL: ", Rest/binary>>) ->
    case binary:split(Rest, <<",">>) of
        [IMEI, IP] -> {call, IMEI, IP};
        _ -> {error, malformed_call}
    end;
decode_request(<<"STAT">>) -> {command, stat};
decode_request(<<"REBOOT">>) -> {command, reboot};
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

-spec decode_response(binary()) ->
          {binary(), non_neg_integer(), binary()} | {error, term()}.
decode_response(Bin) ->
    case binary:split(Bin, <<":">>) of
        [Name, Rest] ->
            case binary:split(Rest, <<",">>) of
                [CodeBin, Data] -> {Name, to_int(CodeBin), Data};
                [CodeBin] -> {Name, to_int(CodeBin), <<>>}
            end;
        _ -> {error, malformed_response}
    end.

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
cmd_name({unknown, _}) -> <<"ERR">>;
cmd_name(Bin) when is_binary(Bin) -> Bin.

to_int(Bin) ->
    try binary_to_integer(Bin) catch _:_ -> ?FAIL end.
