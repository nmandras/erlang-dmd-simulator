%%% @doc WM-E checksums: per-frame XOR and bulk Fletcher-16 (see plan §6).
-module(wme_checksum).

-export([xor_checksum/3, fletcher16/1, fletcher16/3]).

%% XOR of Bin[Start..End], where End follows the plan's convention:
%%   End == 0  -> last byte of Bin (send direction)
%%   End <  0  -> len-1+End (e.g. -1 = second-to-last, exclude trailing checksum)
%%   End >  0  -> that absolute index
-spec xor_checksum(binary(), integer(), integer()) -> byte().
xor_checksum(Bin, Start, End0) ->
    Size = byte_size(Bin),
    End = if End0 =:= 0 -> Size - 1;
             End0 < 0   -> Size - 1 + End0;
             true       -> End0
          end,
    xor_range(Bin, Start, End, 0).

xor_range(_Bin, I, End, Acc) when I > End -> Acc band 16#FF;
xor_range(Bin, I, End, Acc) ->
    xor_range(Bin, I + 1, End, Acc bxor binary:at(Bin, I)).

-spec fletcher16(binary()) -> {byte(), byte()}.
fletcher16(Bin) -> fletcher16(Bin, 0, 0).

%% Returns {MSB, LSB}; the 16-bit value is (MSB bsl 8) bor LSB.
-spec fletcher16(binary(), byte(), byte()) -> {byte(), byte()}.
fletcher16(Bin, InitMSB, InitLSB) ->
    fletch(Bin, 0, byte_size(Bin), InitMSB, InitLSB).

fletch(_Bin, I, Len, MSB, LSB) when I >= Len -> {MSB, LSB};
fletch(Bin, I, Len, MSB, LSB) ->
    MSB2 = (MSB + binary:at(Bin, I)) band 16#FF,
    LSB2 = (LSB + MSB2) band 16#FF,
    fletch(Bin, I + 1, Len, MSB2, LSB2).
