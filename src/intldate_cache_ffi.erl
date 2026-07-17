-module(intldate_cache_ffi).
-export([get_persistent_term/1, put_persistent_term/2, get_ets/1, put_ets/2]).

-define(MISS, '$intldate_cache_miss').
-define(TABLE, intldate_locale_cache).

get_persistent_term(Key) ->
    case persistent_term:get({?MODULE, Key}, ?MISS) of
        ?MISS -> {error, nil};
        Value -> {ok, Value}
    end.

put_persistent_term(Key, Value) ->
    persistent_term:put({?MODULE, Key}, Value),
    Value.

get_ets(Key) ->
    ensure_table(),
    case ets:lookup(?TABLE, Key) of
        [{_, Value}] -> {ok, Value};
        [] -> {error, nil}
    end.

put_ets(Key, Value) ->
    ensure_table(),
    ets:insert(?TABLE, {Key, Value}),
    Value.

ensure_table() ->
    case ets:whereis(?TABLE) of
        undefined -> create_table();
        _ -> ok
    end.

create_table() ->
    Self = self(),
    Ref = make_ref(),
    Pid = spawn(fun() -> owner(Self, Ref) end),
    MRef = erlang:monitor(process, Pid),
    receive
        {Ref, ok} ->
            erlang:demonitor(MRef, [flush]),
            ok;
        {'DOWN', MRef, process, Pid, _} ->
            ensure_table()
    end.

owner(Parent, Ref) ->
    try ets:new(?TABLE, [named_table, public, set, {read_concurrency, true}]) of
        _ ->
            Parent ! {Ref, ok},
            wait()
    catch
        error:badarg -> ok
    end.

wait() ->
    receive _ -> wait() end.
