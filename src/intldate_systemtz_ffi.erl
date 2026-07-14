-module(intldate_systemtz_ffi).
-export([detect/0]).

-define(TZDEFAULT, "/etc/localtime").
-define(TZZONEINFOTAIL, "/zoneinfo/").

detect() ->
    case from_env() of
        {ok, Id} -> {ok, list_to_binary(Id)};
        error ->
            case from_localtime_link() of
                {ok, Id} -> {ok, list_to_binary(Id)};
                error -> {error, nil}
            end
    end.

from_env() ->
    case os:getenv("TZ") of
        false -> error;
        "" -> error;
        Raw ->
            Id = skip_zone_prefix(strip_leading_colon(Raw)),
            case is_valid_olson_id(Id) of
                true -> {ok, Id};
                false -> error
            end
    end.

strip_leading_colon([$: | Rest]) -> Rest;
strip_leading_colon(Id) -> Id.

skip_zone_prefix("posix/" ++ Rest) -> Rest;
skip_zone_prefix("right/" ++ Rest) -> Rest;
skip_zone_prefix(Id) -> Id.

%% Mirrors ICU's putil.c uprv_tzname(): first try to resolve the
%% /etc/localtime symlink chain to an absolute path and pull the zone id
%% out of the "…/zoneinfo/<id>" tail, falling back to the single-level,
%% unresolved readlink target when that fails (e.g. the resolved path
%% doesn't run through a "zoneinfo" directory).
from_localtime_link() ->
    case extract_zone_id(realpath(?TZDEFAULT)) of
        {ok, Id} -> {ok, Id};
        error ->
            case file:read_link(?TZDEFAULT) of
                {ok, Raw} -> extract_zone_id(Raw);
                {error, _} -> error
            end
    end.

realpath(Path) -> realpath(Path, 40).

realpath(_Path, 0) -> _Path;
realpath(Path, N) ->
    case file:read_link(Path) of
        {ok, Target} ->
            Abs = case Target of
                [$/ | _] -> Target;
                _ -> filename:join(filename:dirname(Path), Target)
            end,
            realpath(normalize(Abs), N - 1);
        {error, _} ->
            Path
    end.

normalize(Path) ->
    Segments = string:lexemes(Path, "/"),
    Stack = lists:foldl(fun
        (".", Acc) -> Acc;
        ("..", []) -> [];
        ("..", [_ | Rest]) -> Rest;
        (Seg, Acc) -> [Seg | Acc]
    end, [], Segments),
    case lists:reverse(Stack) of
        [] -> "/";
        Ordered -> lists:flatten([["/", S] || S <- Ordered])
    end.

extract_zone_id(Path) ->
    case after_marker(Path, ?TZZONEINFOTAIL) of
        {ok, "posixrules"} -> error;
        {ok, After} ->
            Id = skip_zone_prefix(After),
            case is_valid_olson_id(Id) of
                true -> {ok, Id};
                false -> error
            end;
        error -> error
    end.

%% Returns what follows the first occurrence of Marker in Full, walking
%% both lists by recursion instead of indexing into them.
after_marker(Full, Marker) ->
    case drop_prefix(Full, Marker) of
        {ok, Rest} -> {ok, Rest};
        error ->
            case Full of
                [] -> error;
                [_ | Rest] -> after_marker(Rest, Marker)
            end
    end.

drop_prefix(Full, []) -> {ok, Full};
drop_prefix([Ch | FullRest], [Ch | MarkerRest]) -> drop_prefix(FullRest, MarkerRest);
drop_prefix(_Full, _Marker) -> error.

%% Port of ICU's isValidOlsonID(): rejects abbreviated zone specs like
%% "PST8PDT5" while accepting Olson ids (letters/underscores/slashes,
%% optionally with a numeric suffix such as "Etc/GMT+11").
is_valid_olson_id(Id) ->
    case skip_non_digit(Id) of
        [] -> true;
        Rest ->
            case Id of
                "PST8PDT" -> true;
                "MST7MDT" -> true;
                "CST6CDT" -> true;
                "EST5EDT" -> true;
                _ -> skip_digit(Rest, 2) =:= []
            end
    end.

skip_non_digit([]) -> [];
skip_non_digit([$, | _] = Rest) -> Rest;
skip_non_digit([Ch | Rest] = Full) ->
    case is_digit(Ch) of
        true -> Full;
        false -> skip_non_digit(Rest)
    end.

skip_digit(Rest, 0) -> Rest;
skip_digit([], _Count) -> [];
skip_digit([Ch | Rest] = Full, Count) ->
    case is_digit(Ch) of
        true -> skip_digit(Rest, Count - 1);
        false -> Full
    end.

is_digit(Ch) -> Ch >= $0 andalso Ch =< $9.
