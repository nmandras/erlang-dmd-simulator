%%% @doc Device inventory CSV shared by the agent and the management server.
%%%
%%% Format (an optional `imei,...' header and `#' comment lines are skipped):
%%% ```
%%% imei,ip,port,callperiod
%%% 101000000000001,127.0.0.2,6000,10
%%% '''
%%% `callperiod' is in seconds on disk; it is parsed into `callperiod_ms'.
-module(dmd_csv).

-export([read/1, write/2, generate/5, generate_file/2]).

-type row() :: #{imei := binary(),
                 ip := inet:ip_address(),
                 port := inet:port_number(),
                 callperiod_ms := non_neg_integer()}.
-export_type([row/0]).

%% Defaults for the standard fleet: IMEIs from 101000000000001, loopback IPs
%% from 127.0.0.2, shared port 6000, 10-second call period.
-define(START_IMEI, 101000000000001).
-define(FIRST_OCTET, 2).
-define(PORT, 6000).
-define(PERIOD_SEC, 10).

-spec read(file:name_all()) -> {ok, [row()]} | {error, term()}.
read(Path) ->
    case file:read_file(Path) of
        {ok, Bin} -> {ok, parse(Bin)};
        Err -> Err
    end.

-spec write(file:name_all(), [row()]) -> ok | {error, term()}.
write(Path, Rows) ->
    Header = <<"imei,ip,port,callperiod\n">>,
    Body = [row_to_line(R) || R <- Rows],
    file:write_file(Path, [Header | Body]).

%% Build `Count' rows of inventory.
-spec generate(non_neg_integer(), integer(), 1..254,
               inet:port_number(), non_neg_integer()) -> [row()].
generate(Count, StartImei, FirstOctet, Port, PeriodSec) ->
    [#{imei => integer_to_binary(StartImei + I - 1),
       ip => {127, 0, 0, FirstOctet + I - 1},
       port => Port,
       callperiod_ms => PeriodSec * 1000}
     || I <- lists:seq(1, Count)].

%% Generate and write the standard fleet of `Count' devices.
-spec generate_file(file:name_all(), non_neg_integer()) -> ok | {error, term()}.
generate_file(Path, Count) ->
    write(Path, generate(Count, ?START_IMEI, ?FIRST_OCTET, ?PORT, ?PERIOD_SEC)).

%%====================================================================
%% Internal
%%====================================================================

parse(Bin) ->
    Lines = binary:split(Bin, [<<"\n">>, <<"\r\n">>], [global]),
    lists:filtermap(fun parse_line/1, Lines).

parse_line(Line0) ->
    Line = trim(Line0),
    case is_data_line(Line) of
        false ->
            false;
        true ->
            case binary:split(Line, <<",">>, [global]) of
                [Imei, Ip, Port, Period] ->
                    {true, #{imei => trim(Imei),
                             ip => parse_ip(Ip),
                             port => binary_to_integer(trim(Port)),
                             callperiod_ms => binary_to_integer(trim(Period)) * 1000}};
                _ ->
                    false
            end
    end.

is_data_line(<<>>) -> false;
is_data_line(<<"#", _/binary>>) -> false;
is_data_line(<<"imei", _/binary>>) -> false;
is_data_line(_) -> true.

row_to_line(#{imei := Imei, ip := Ip, port := Port, callperiod_ms := Ms}) ->
    io_lib:format("~s,~s,~b,~b~n",
                  [Imei, dmd_proto:ip_to_bin(Ip), Port, Ms div 1000]).

parse_ip(Bin) ->
    case inet:parse_address(binary_to_list(trim(Bin))) of
        {ok, Addr} -> Addr;
        {error, _} -> {127, 0, 0, 1}
    end.

trim(Bin) -> iolist_to_binary(string:trim(Bin)).
