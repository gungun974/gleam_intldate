-module(save_ffi).
-export([save/2, encode/1]).

encode(Value) ->
    term_to_binary(Value, [{compressed, 6}]).

save(Id, Data) ->
    Path = path(Id),
    ok = filelib:ensure_dir(Path),
    Bin = term_to_binary(Data, [{compressed, 9}]),
    ok = file:write_file(Path, Bin),
    nil.

path(Id) ->
    PrivDir = unicode:characters_to_binary(code:priv_dir(intldate)),
    <<PrivDir/binary, "/generated/", Id/binary, ".etf">>.
