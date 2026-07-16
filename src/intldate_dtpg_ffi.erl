-module(intldate_dtpg_ffi).
-export([distance/4]).

-define(EXTRA_FIELD, 65536).
-define(MISSING_FIELD, 4096).
-define(FIELD_COUNT, 16).

%% Gleam cannot select a custom-type field dynamically by index.
%% A case-based equivalent adds dispatch and allocations in this hot loop,
%% while Erlang's element/2 provides direct O(1) tuple access.
distance(Mine, Theirs, IncludeMask, Limit) ->
    distance(0, Mine, Theirs, IncludeMask, Limit, 0, 0, 0).

distance(Index, _Mine, _Theirs, _IncludeMask, _Limit, Result, Missing, Extra)
        when Index >= ?FIELD_COUNT ->
    {Result, {distance_info, Missing, Extra}};
distance(_Index, _Mine, _Theirs, _IncludeMask, Limit, Result, Missing, Extra)
        when Result > Limit ->
    {Result, {distance_info, Missing, Extra}};
distance(Index, Mine, Theirs, IncludeMask, Limit, Result, Missing, Extra) ->
    Mask = 1 bsl Index,
    MyRaw = element(Index + 2, Mine),
    MyType = case IncludeMask band Mask of
        0 -> 0;
        _ -> MyRaw
    end,
    OtherType = element(Index + 2, Theirs),
    case MyType of
        OtherType ->
            distance(
                Index + 1,
                Mine,
                Theirs,
                IncludeMask,
                Limit,
                Result,
                Missing,
                Extra
            );
        0 ->
            distance(
                Index + 1,
                Mine,
                Theirs,
                IncludeMask,
                Limit,
                Result + ?EXTRA_FIELD,
                Missing,
                Extra bor Mask
            );
        _ when OtherType =:= 0 ->
            distance(
                Index + 1,
                Mine,
                Theirs,
                IncludeMask,
                Limit,
                Result + ?MISSING_FIELD,
                Missing bor Mask,
                Extra
            );
        _ ->
            distance(
                Index + 1,
                Mine,
                Theirs,
                IncludeMask,
                Limit,
                Result + abs(MyType - OtherType),
                Missing,
                Extra
            )
    end.
