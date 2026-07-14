-module(intldate_icudata_ffi).
-export([load_bundle/2, cache_get/1, cache_put/2, classify_node/1, decode_zoneinfo/1]).

classify_node(Value) when is_integer(Value) -> {raw_int, Value};
classify_node(Value) when is_binary(Value) -> {raw_string, Value};
classify_node(Value) when is_list(Value) -> {raw_array, Value};
classify_node(#{<<"$alias">> := Alias}) -> {raw_alias, Alias};
classify_node(#{<<"$int_vector">> := Vector}) -> {raw_int_vector, Vector};
classify_node(#{<<"$binary">> := Bytes}) -> {raw_binary, Bytes};
classify_node(Value) when is_map(Value) -> {raw_table, maps:to_list(Value)}.

-define(MISS, '$intldate_cache_miss').

cache_get(Key) ->
    case persistent_term:get({?MODULE, Key}, ?MISS) of
        ?MISS -> {error, nil};
        Value -> {ok, Value}
    end.

cache_put(Key, Value) ->
    persistent_term:put({?MODULE, Key}, Value),
    Value.

load_bundle(DataPath, Name) ->
    Dir = case DataPath of
        <<>> -> default_dir();
        _ -> DataPath
    end,
    Path = <<Dir/binary, "/", Name/binary, ".etf">>,
    case file:read_file(Path) of
        {ok, Bin} -> {ok, binary_to_term(Bin)};
        {error, _} -> {error, nil}
    end.

default_dir() ->
    PrivDir = unicode:characters_to_binary(code:priv_dir(intldate)),
    <<PrivDir/binary, "/icudata">>.

decode_zoneinfo(DataPath) ->
    case load_bundle(DataPath, <<"zoneinfo64">>) of
        {error, _} -> {error, nil};
        {ok, #{<<"Names">> := Names, <<"Regions">> := Regions,
               <<"Zones">> := Zones, <<"Rules">> := Rules}} ->
            {ok, {zone_info64,
                  indexed(Names),
                  name_index(Names),
                  indexed(Regions),
                  indexed([zone_entry(Z) || Z <- Zones]),
                  maps:map(fun(_K, V) -> int_vector(V) end, Rules),
                  length(Names)}};
        {ok, _} -> {error, nil}
    end.

indexed(List) ->
    maps:from_list(lists:zip(lists:seq(0, length(List) - 1), List)).

name_index(Names) ->
    maps:from_list(lists:zip(Names, lists:seq(0, length(Names) - 1))).

int_vector(#{<<"$int_vector">> := Vector}) -> Vector;
int_vector(_) -> [].

zone_entry(Index) when is_integer(Index) -> {zone_link, Index};
zone_entry(Zone) when is_map(Zone) ->
    {zone_record,
     opt_vector(Zone, <<"trans">>),
     opt_vector(Zone, <<"transPre32">>),
     opt_vector(Zone, <<"transPost32">>),
     opt_vector(Zone, <<"typeOffsets">>),
     opt_binary(Zone, <<"typeMap">>),
     opt_string(Zone, <<"finalRule">>),
     opt_int(Zone, <<"finalRaw">>),
     opt_int(Zone, <<"finalYear">>)}.

opt_vector(Zone, Key) ->
    case Zone of
        #{Key := #{<<"$int_vector">> := Vector}} -> Vector;
        _ -> []
    end.

opt_binary(Zone, Key) ->
    case Zone of
        #{Key := #{<<"$binary">> := Bytes}} -> {some, Bytes};
        _ -> none
    end.

opt_string(Zone, Key) ->
    case Zone of
        #{Key := Value} when is_binary(Value) -> {some, Value};
        _ -> none
    end.

opt_int(Zone, Key) ->
    case Zone of
        #{Key := Value} when is_integer(Value) -> Value;
        _ -> 0
    end.
