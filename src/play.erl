-module(play).

-export([
	test_avg/4,
    p_start/0,
    p_start/1,
    p_stop/0,
    p_show/0,
    while/1
]).



test_avg(M, F, A, N) when N > 0 ->
    L = test_loop(M, F, A, N, []),
    Length = length(L),
    Min = lists:min(L),
    Max = lists:max(L),
    Med = lists:nth(round((Length / 2)), lists:sort(L)),
    Avg = round(lists:foldl(fun(X, Sum) -> X + Sum end, 0, L) / Length),
    io:format("Range: ~b - ~b mics~n"
	      "Median: ~b mics~n"
	      "Average: ~b mics~n",
	      [Min, Max, Med, Avg]),
    Med.

test_loop(_M, _F, _A, 0, List) ->
    List;
test_loop(M, F, A, N, List) ->
    {T, _Result} = timer:tc(M, F, A),
    test_loop(M, F, A, N - 1, [T|List]).

 p_start()->  p_start(processes()).
 p_start(Processes)-> fprof:trace([start,{procs,Processes}]).

 p_stop()-> 
    fprof:trace([stop]),
    fprof:profile().

 p_show()->
    fprof:analyse().

while(Fun) when is_function(Fun,0)->
    case Fun() of
        true -> while(Fun);
        _ -> finished
    end.