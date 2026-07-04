-module(intldate_time_ffi).
-export([system_time_zone/0]).

system_time_zone() ->
    case from_env() of
        {ok, Zone} -> {ok, Zone};
        error ->
            case from_localtime_symlink() of
                {ok, Zone} -> {ok, Zone};
                error -> from_timezone_file()
            end
    end.

from_env() ->
    case os:getenv("TZ") of
        false -> error;
        [] -> error;
        [$: | Rest] -> zoneinfo_suffix(unicode:characters_to_binary(Rest));
        Tz -> zoneinfo_suffix(unicode:characters_to_binary(Tz))
    end.

from_localtime_symlink() ->
    case file:read_link("/etc/localtime") of
        {ok, Target} -> zoneinfo_suffix(unicode:characters_to_binary(Target));
        {error, _} -> error
    end.

from_timezone_file() ->
    case file:read_file("/etc/timezone") of
        {ok, Bin} ->
            case string:trim(Bin) of
                <<>> -> {error, nil};
                Zone -> {ok, Zone}
            end;
        {error, _} -> {error, nil}
    end.

zoneinfo_suffix(Path) ->
    case string:split(Path, <<"zoneinfo/">>, trailing) of
        [_, Zone] when Zone =/= <<>> -> {ok, Zone};
        _ ->
            case binary:match(Path, <<"/">>) of
                nomatch -> error;
                _ -> {ok, Path}
            end
    end.
