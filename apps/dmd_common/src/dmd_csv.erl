%%% @doc Device inventory CSV, shared by the agent and the management server.
%%%
%%% Columns:
%%%   IMEI,IP,MgmtPort,PortSSH,DeviceType,TLSEnable,Reptime,
%%%   LoginName,LoginPass,EquipmentGroup,StatInCall,Comments
%%%
%%% DeviceType 1 = wmr (CALL + STAT/REBOOT/SECLOG text listener),
%%% DeviceType 2 = wme (CALL + WM-E config-read listener).
%%% StatInCall 1 = WME devices embed status in the periodic CALL payload.
%%% Reptime is the CALL period in seconds. TLSEnable/PortSSH/LoginName/
%%% LoginPass/EquipmentGroup/Comments are stored as metadata.
-module(dmd_csv).

-export([read/1, write/2, generate/3, generate_scale/3, generate_file/3, generate_file/4]).

-type row() :: #{imei := binary(), ip := inet:ip4_address(),
                 port := inet:port_number(), ssh_port := inet:port_number(),
                 device_type := 1 | 2, tls := boolean(),
                 period_ms := non_neg_integer(),
                 stat_in_call := boolean(),
                 login_name := binary(), login_pass := binary(),
                 group := binary(), comments := binary()}.
-export_type([row/0]).

-define(HEADER,
        <<"IMEI,IP,MgmtPort,PortSSH,DeviceType,TLSEnable,Reptime,"
          "LoginName,LoginPass,EquipmentGroup,StatInCall,Comments\n">>).

-spec read(file:name_all()) -> {ok, [row()]} | {error, term()}.
read(Path) ->
    case file:read_file(Path) of
        {ok, Bin} -> {ok, parse(Bin)};
        Err -> Err
    end.

-spec write(file:name_all(), [row()]) -> ok | {error, term()}.
write(Path, Rows) ->
    file:write_file(Path, [?HEADER | [row_to_line(R) || R <- Rows]]).

%% Build Wmr type-1 rows followed by Wme type-2 rows. Opts keys: start_imei,
%% base_ip, mgmt_port, period_sec (all optional).
-spec generate(non_neg_integer(), non_neg_integer(), map()) -> [row()].
generate(Wmr, Wme, Opts) ->
    StartImei = maps:get(start_imei, Opts, 1),
    Base = maps:get(base_ip, Opts, {127, 10, 0, 1}),
    Port = maps:get(mgmt_port, Opts, 6000),
    Period = maps:get(period_sec, Opts, 30),
    StatInCall = maps:get(stat_in_call, Opts, false),
    Total = Wmr + Wme,
    [row(StartImei + I, ip_add(Base, I), Port,
         type_of(I, Wmr), Period, StatInCall) || I <- lists:seq(0, Total - 1)].

%% Scale generation: spread IPs across the 127.0.0.0/8 loopback block.
-spec generate_scale(non_neg_integer(), non_neg_integer(), non_neg_integer()) -> [row()].
generate_scale(Wmr, Wme, PeriodSec) ->
    generate(Wmr, Wme, #{start_imei => 1, base_ip => {127, 0, 0, 2},
                         mgmt_port => 6000, period_sec => PeriodSec}).

-spec generate_file(file:name_all(), non_neg_integer(), non_neg_integer()) ->
          ok | {error, term()}.
generate_file(Path, Wmr, Wme) ->
    generate_file(Path, Wmr, Wme, #{}).

-spec generate_file(file:name_all(), non_neg_integer(), non_neg_integer(), map()) ->
          ok | {error, term()}.
generate_file(Path, Wmr, Wme, Opts) ->
    Defaults = #{start_imei => 101000000000001,
                 base_ip => {127, 10, 0, 1},
                 mgmt_port => 6000,
                 period_sec => 10},
    write(Path, generate(Wmr, Wme, maps:merge(Defaults, Opts))).

%%====================================================================
%% Internal
%%====================================================================

type_of(I, Wmr) when I < Wmr -> 1;
type_of(_I, _Wmr) -> 2.

row(ImeiInt, IP, Port, DeviceType, PeriodSec, StatInCallWme) ->
    #{imei => iolist_to_binary(io_lib:format("~15..0b", [ImeiInt])),
      ip => IP,
      port => Port,
      ssh_port => 22,
      device_type => DeviceType,
      tls => false,
      period_ms => PeriodSec * 1000,
      stat_in_call => DeviceType =:= 2 andalso StatInCallWme,
      login_name => <<"root">>,
      login_pass => <<"admin">>,
      group => <<"Group-1">>,
      comments => <<>>}.

ip_add({A, B, C, D}, N) ->
    X = (A bsl 24) bor (B bsl 16) bor (C bsl 8) bor D,
    Y = X + N,
    {(Y bsr 24) band 16#FF, (Y bsr 16) band 16#FF,
     (Y bsr 8) band 16#FF, Y band 16#FF}.

parse(Bin) ->
    Lines = [L || L <- binary:split(Bin, [<<"\n">>, <<"\r\n">>], [global]),
                  L =/= <<>>],
    case Lines of
        [] ->
            [];
        [First | Rest] ->
            HasStatCol = header_has_stat_in_call(trim(First)),
            lists:filtermap(fun(L) -> parse_line(trim(L), HasStatCol) end, Rest)
    end.

header_has_stat_in_call(<<"IMEI", _/binary>> = Header) ->
    binary:match(Header, <<"StatInCall">>) =/= nomatch;
header_has_stat_in_call(_) ->
    false.

parse_line(Line, HasStatCol) ->
    case is_data_line(Line) of
        false ->
            false;
        true ->
            Fields = binary:split(Line, <<",">>, [global]),
            build_row(Fields, HasStatCol)
    end.

build_row([IMEI, IP, MgmtPort, SSH, DType, TLS, Rep,
           LName, LPass, Group, StatInCall | CommentsParts], true) ->
    {true, #{imei => trim(IMEI),
             ip => parse_ip(IP),
             port => to_int(MgmtPort),
             ssh_port => to_int(SSH),
             device_type => to_int(DType),
             tls => to_int(TLS) =:= 1,
             period_ms => to_int(Rep) * 1000,
             stat_in_call => to_int(StatInCall) =:= 1,
             login_name => trim(LName),
             login_pass => trim(LPass),
             group => trim(Group),
             comments => trim(join_commas(CommentsParts))}};
build_row([IMEI, IP, MgmtPort, SSH, DType, TLS, Rep,
           LName, LPass, Group | CommentsParts], false) ->
    {true, #{imei => trim(IMEI),
             ip => parse_ip(IP),
             port => to_int(MgmtPort),
             ssh_port => to_int(SSH),
             device_type => to_int(DType),
             tls => to_int(TLS) =:= 1,
             period_ms => to_int(Rep) * 1000,
             stat_in_call => false,
             login_name => trim(LName),
             login_pass => trim(LPass),
             group => trim(Group),
             comments => trim(join_commas(CommentsParts))}};
build_row(_Fields, _HasStatCol) ->
    false.

is_data_line(<<>>) -> false;
is_data_line(<<"#", _/binary>>) -> false;
is_data_line(<<"IMEI", _/binary>>) -> false;
is_data_line(_) -> true.

row_to_line(#{imei := IMEI, ip := IP, port := Port, ssh_port := SSH,
              device_type := DType, tls := TLS, period_ms := Ms,
              stat_in_call := StatInCall,
              login_name := LName, login_pass := LPass,
              group := Group, comments := Comments}) ->
    io_lib:format("~s,~s,~b,~b,~b,~b,~b,~s,~s,~s,~b,~s~n",
                  [IMEI, dmd_proto:ip_to_bin(IP), Port, SSH, DType,
                   bool_int(TLS), Ms div 1000, LName, LPass, Group,
                   bool_int(StatInCall), Comments]).

bool_int(true) -> 1;
bool_int(false) -> 0.

join_commas([]) -> <<>>;
join_commas([X]) -> X;
join_commas(Parts) -> iolist_to_binary(lists:join(<<",">>, Parts)).

to_int(Bin) ->
    try binary_to_integer(trim(Bin)) catch _:_ -> 0 end.

parse_ip(Bin) ->
    case inet:parse_address(binary_to_list(trim(Bin))) of
        {ok, Addr} -> Addr;
        {error, _} -> {127, 0, 0, 1}
    end.

trim(Bin) -> iolist_to_binary(string:trim(Bin)).
