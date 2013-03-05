-include_lib("eunit/include/eunit.hrl").

-define(BUILD_TESTS(Test),
	lists:foldl(fun({Name,Call,Mock,Response},Acc)->
		Acc ++ [{Name,fun()->
			
			%% mock all the objects that we need to
			build_module(Mock),

			Result = case Call of
				{Mod,Func,Args} ->
					io:format("~ncalling apply"),
					%% we make the call
					apply(Mod,Func,Args);
				{Fun,Args} ->
					io:format("~ncalling fun apply"),
					%% we make the call
					apply(Fun,Args);
				Func1 when is_function(Func1,0) ->
					io:format("~ncalling fun"),
					Func1();
				Call ->
					throw({wrong,Call})
			end,
			io:format("~nresult ~p",[Result]),

			%% now we unmock all the objects
			unbuild_module(Mock),

			case Response of
				Resp when is_function(Resp,1) ->
					?assert(Resp(Result));
				Response ->
					%% now we do the assertions
					?assertMatch(Response,Result)
			end
		end}]
	end,[{"passing test",fun()-> ok end}],Tests)).


%% mock a module without options
unbuild_module([{Module,Funcs}|Tail])->
	unbuild_module([{Module,[],Funcs}]),
	unbuild_module(Tail);


%% mock a module with options
unbuild_module([{Module,_,_}|Tail])->
	% start the module
	meck:unload(Module),

	%% remove any pids that have been registered
	Name = list_to_atom("eunit_queue_for_" ++ atom_to_list(Module)),
	case whereis(Name) of
		undefined -> ok;
		_ ->
			Name ! shutdown,
			unregister(Name)
	end,
	unbuild_module(Tail);
unbuild_module([])-> ok.

%% mock a module without options
build_module([{Module,Funcs}|Tail])->
	build_module([{Module,[],Funcs}]),
	build_module(Tail);


%% mock a module with options
build_module([{Module,Opts,Funcs}|Tail])->
	io:format("~nmeck ~p",[Module]),
	% start the module
	meck:new(Module,Opts),
	build_funcs(Module,Funcs),
	build_module(Tail);
build_module([])-> ok.

%% mock a specific function or behavior
build_funcs(Module,[{Func1,Fun}|Tail]) when is_function(Fun) ->
	io:format(" '~p'",[Func1]),
	% mock the function that is part of the module
	meck:expect(Module,Func1,Fun),
	build_funcs(Module,Tail);

build_funcs(Module,Data = [{Func1,Behaviours}|Tail]) ->
	Name = list_to_atom("eunit_queue_for_" ++ atom_to_list(Module)),
	Pid = case whereis(Name) of
		undefined -> 
			io:format(" S_pid:~p",[Name]),
			P = spawn(fun()-> call_response(Data,orddict:new()) end),
			register(Name,P),
			P;
		Other -> 
			io:format(" R_pid:~p",[Name]),
			Other
	end,
	io:format(":~p",[Pid]),
	build_behaviors(Pid,Module,Func1,Behaviours),
	build_funcs(Module,Tail);

build_funcs(_,[]) -> ok.


handle(Func,Pid,Args) ->
	io:format("~nh: ~p ~p",[Func,Args]),
	Pid ! {call,self(),{Func,Args}},
	receive
		{error,function_clause} -> throw({error,function_clause,{Func,Args}});
		{error,Msg} -> throw({error,Msg});
		{ok,Ret} -> Ret
	end.

%% this is a catch all
build_behaviors(Pid,Module,Func1,{all,Length,Commands}) ->
	build_behaviors(Pid,Module,Func1,[{lists:seq(1,Length),Commands}]);

%% mock a behavior so that we can use it
build_behaviors(Pid,Module,Func1,[{Args,_} | Tail]) ->
	try
		F = case length(Args) of
			0 -> fun() -> handle(Func1,Pid,[]) end;
			1 -> fun(A) -> handle(Func1,Pid,[A]) end;
			2 -> fun(A,B) -> handle(Func1,Pid,[A,B]) end;
			3 -> fun(A,B,C) -> handle(Func1,Pid,[A,B,C]) end;
			4 -> fun(A,B,C,D) -> handle(Func1,Pid,[A,B,C,D]) end;
			5 -> fun(A,B,C,D,E) -> handle(Func1,Pid,[A,B,C,D,E]) end;
			6 -> fun(A,B,C,D,E,F) -> handle(Func1,Pid,[A,B,C,D,E,F]) end
		end,
		build_funcs(Module,[{Func1,F}]),
		io:format(":b",[])
	catch
		_:_ -> ok
	end,
	build_behaviors(Pid,Module,Func1,Tail);
build_behaviors(_,_,_,[]) -> 
	io:format(" done with behavior"),
	ok.


call_response(Data,Queue)->
	receive 
		shutdown -> ok;
		{call,Pid,{Func,Args}} ->
			case lists:keyfind(Func,1,Data) of
				false -> Pid ! {error,not_mocked};
				{Func,Args_commands} ->
					case Args_commands of
						%% these are command that need to be run no matter what the arg list is.
						{all,_,Commands} -> 
							case do(Commands,Queue) of
								{ok,NewQ,Ret} -> Pid ! {ok,Ret}, call_response(Data,NewQ);
								Other -> Pid ! Other
							end;
						%% these are commands that depend on the arg list
						_ ->
							case lists:keyfind(Args,1,Args_commands) of
								false -> 
									io:fwrite(user,"~n### function clause ###~nargs: ~p~ncommands: ~p ~n",[Args,Args_commands]),
									Pid ! {error,function_clause};
								{Args,Commands} -> 
									case do(Commands,Queue) of
										{ok,NewQ,Ret} -> Pid ! {ok,Ret}, call_response(Data,NewQ);
										Other -> Pid ! Other
									end
							end
					end
			end
	end.


do([{push,Key,Data}|Tail],Master)->
	Q = case orddict:find(Key,Master) of
		error -> queue:new();
		{ok,D} -> D
	end,
	NewQ = queue:in(Data,Q),
	NewM = orddict:store(Key,NewQ,Master),

	%% if this is the last command we return 'ok'
	%% otherwise we continue running commands
	case Tail of
		[] -> {ok,NewM,ok};
		_ -> do(Tail,NewM)
	end;

do([{pop,Key}|Tail],Master) ->
	case orddict:find(Key,Master) of
		error -> {error,no_val_in_q};
		{ok,Q} -> 
			{{value,Ret},NewQ} = queue:out(Q),
			NewM = orddict:store(Key,NewQ,Master),

			%% if this is the last command we return the value,
			%% otherwise we eat the value.
			case Tail of
				[] -> {ok,NewM,Ret};
				_ -> do(Tail,NewM)
			end
	end;
	
do([{ret,Ret}],Q) -> {ok,Q,Ret};
do([{ret,_}|_],_) -> {error,invalid_ret};
do([],_) -> {error,no_ret_val}.