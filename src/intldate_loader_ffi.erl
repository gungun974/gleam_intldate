-module(intldate_loader_ffi).
-export([load/1, cache_get/1, cache_put/2, decode/1, constructor_name/1]).

-define(MISS, '$intldate_loader_cache_miss').

cache_get(Key) ->
    case persistent_term:get({?MODULE, Key}, ?MISS) of
        ?MISS -> {error, nil};
        Value -> {ok, Value}
    end.

cache_put(Key, Value) ->
    persistent_term:put({?MODULE, Key}, Value),
    Value.

decode(Bin) ->
    binary_to_term(Bin).

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
