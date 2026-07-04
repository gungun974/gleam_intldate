-module(intldate_cache_ffi).
-export([lookup/1, insert/2]).

-define(TABLE, intldate_locale_cache).

lookup(Key) ->
    ensure_table(),
    case ets:lookup(?TABLE, Key) of
        [{_, Value}] -> {ok, Value};
        [] -> {error, nil}
    end.

insert(Key, Value) ->
    ensure_table(),
    ets:insert(?TABLE, {Key, Value}),
    nil.

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
