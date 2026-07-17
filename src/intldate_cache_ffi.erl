-module(intldate_cache_ffi).
-export([get_persistent_term/1, put_persistent_term/2, get_ets/1, put_ets/2]).

-define(MISS, '$intldate_cache_miss').
-define(TABLE, intldate_locale_cache).
-define(OWNER, intldate_locale_cache_owner).

-define(DEFAULT_MAX_ENTRIES, 1024).
-define(DEFAULT_MAX_IDLE_MS, 1800000).
-define(DEFAULT_SWEEP_MS, 60000).

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
        [{_, Value, Last}] ->
            touch(Key, Last),
            {ok, Value};
        [] ->
            {error, nil}
    end.

put_ets(Key, Value) ->
    ensure_table(),
    ets:insert(?TABLE, {Key, Value, erlang:monotonic_time()}),
    maybe_trigger_eviction(),
    Value.

touch(Key, Last) ->
    Now = erlang:monotonic_time(),
    case Now - Last > refresh_interval() of
        true ->
            catch ets:update_element(?TABLE, Key, {3, Now}),
            ok;
        false ->
            ok
    end.

refresh_interval() ->
    erlang:convert_time_unit(1, second, native).

maybe_trigger_eviction() ->
    case ets:info(?TABLE, size) > max_entries() of
        true ->
            case whereis(?OWNER) of
                undefined -> ok;
                Pid -> Pid ! evict, ok
            end;
        false ->
            ok
    end.

max_entries() ->
    env(cache_max_entries, ?DEFAULT_MAX_ENTRIES).

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
    try
        ets:new(?TABLE, [
            named_table,
            public,
            set,
            {read_concurrency, true},
            {write_concurrency, true}
        ])
    of
        _ ->
            catch register(?OWNER, self()),
            Cfg = load_config(),
            Parent ! {Ref, ok},
            schedule_sweep(Cfg),
            loop(Cfg)
    catch
        error:badarg -> ok
    end.

load_config() ->
    #{
        max_entries => env(cache_max_entries, ?DEFAULT_MAX_ENTRIES),
        max_idle => erlang:convert_time_unit(
            env(cache_max_idle_ms, ?DEFAULT_MAX_IDLE_MS),
            millisecond,
            native
        ),
        sweep_ms => env(cache_sweep_ms, ?DEFAULT_SWEEP_MS)
    }.

env(Key, Default) ->
    case application:get_env(intldate, Key) of
        {ok, V} when is_integer(V), V >= 0 -> V;
        _ -> Default
    end.

schedule_sweep(#{sweep_ms := Ms}) ->
    erlang:send_after(Ms, self(), sweep).

loop(Cfg) ->
    receive
        evict ->
            drain_evict(),
            enforce_capacity(Cfg),
            loop(Cfg);
        sweep ->
            purge_idle(Cfg),
            enforce_capacity(Cfg),
            schedule_sweep(Cfg),
            loop(Cfg);
        _ ->
            loop(Cfg)
    end.

drain_evict() ->
    receive
        evict -> drain_evict()
    after 0 -> ok
    end.

purge_idle(#{max_idle := 0}) ->
    ok;
purge_idle(#{max_idle := MaxIdle}) ->
    Threshold = erlang:monotonic_time() - MaxIdle,
    ets:select_delete(?TABLE, [{{'_', '_', '$1'}, [{'<', '$1', Threshold}], [true]}]),
    ok.

enforce_capacity(#{max_entries := Max}) ->
    case ets:info(?TABLE, size) of
        Size when Size > Max ->
            Low = Max * 9 div 10,
            NEvict = Size - Low,
            Entries = ets:select(?TABLE, [{{'$1', '_', '$2'}, [], [{{'$2', '$1'}}]}]),
            Victims = lists:sublist(lists:sort(Entries), NEvict),
            [ets:delete(?TABLE, K) || {_, K} <- Victims],
            ok;
        _ ->
            ok
    end.
