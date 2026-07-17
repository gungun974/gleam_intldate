-module(intldate_loader_ffi).
-export([load/1, decode_etf/1, constructor_name/1]).

decode_etf(Bin) ->
    try
        {ok, binary_to_term(Bin, [safe])}
    catch
        error:badarg -> {error, <<"invalid ETF data">>}
    end.

load(Id) ->
    Path = path(Id),
    case file:read_file(Path) of
        {ok, Bin} ->
            try
                {ok, binary_to_term(Bin, [safe])}
            catch
                error:badarg -> {error, <<"invalid ETF data">>}
            end;
        {error, Reason} ->
            {error, atom_to_binary(Reason)}
    end.

constructor_name(Value) when is_atom(Value) ->
    {ok, atom_to_binary(Value)};
constructor_name(Value) when is_tuple(Value), tuple_size(Value) > 0 ->
    case element(1, Value) of
        Name when is_atom(Name) -> {ok, atom_to_binary(Name)};
        _ -> {error, nil}
    end;
constructor_name(_) ->
    {error, nil}.

path(Id) ->
    PrivDir = unicode:characters_to_binary(code:priv_dir(intldate)),
    <<PrivDir/binary, "/generated/", Id/binary, ".etf">>.
