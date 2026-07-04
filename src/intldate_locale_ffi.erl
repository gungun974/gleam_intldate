-module(intldate_locale_ffi).
-export([load_locale_data/1, load_chinese_data/0]).

load_locale_data(Locale) ->
    load_map(Locale).

priv_directory() ->
    unicode:characters_to_binary(code:priv_dir(intldate)).

load_chinese_data() ->
    PrivDir = priv_directory(),
    case file:read_file(<<PrivDir/binary, "/chinese.etf">>) of
        {ok, Bin} -> {ok, binary_to_term(Bin)};
        {error, _} -> {error, nil}
    end.

load_map(Locale) ->
    PrivDir = priv_directory(),
    Path = <<PrivDir/binary, "/locale/", Locale/binary, ".etf">>,
    case file:read_file(Path) of
        {ok, Bin} ->
            Map = binary_to_term(Bin),
            case maps:take(<<"extend">>, Map) of
                {Parent, Rest} when is_binary(Parent) ->
                    case load_map(Parent) of
                        {ok, ParentMap} -> {ok, deep_merge(ParentMap, Rest)};
                        {error, nil} -> {ok, Rest}
                    end;
                _ ->
                    {ok, Map}
            end;
        {error, _} ->
            {error, nil}
    end.

deep_merge(Base, Override) when is_map(Base), is_map(Override) ->
    {Unset, Overrides} =
        case maps:take(<<"$unset">>, Override) of
            {UnsetList, Rest} -> {UnsetList, Rest};
            error -> {[], Override}
        end,
    Merged = maps:fold(
        fun(Key, Value, Acc) ->
            case maps:find(Key, Acc) of
                {ok, BaseValue} -> maps:put(Key, deep_merge(BaseValue, Value), Acc);
                error -> maps:put(Key, Value, Acc)
            end
        end,
        Base,
        Overrides
    ),
    lists:foldl(fun(Key, Acc) -> maps:remove(Key, Acc) end, Merged, Unset);
deep_merge(_Base, Override) ->
    Override.
