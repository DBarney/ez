-define(VAR(N,D,T),
	fun(Name,Default,Type) -> % lambda used to preserve name space. will only show a warning if a name is taken and Result__ is not visible outside of fun
		case {Type,os:getenv(Name)} of
	  		{_,false} -> Default;
			{integer,Result__} -> list_to_integer(Result__);
			{binary,Result__} -> list_to_binary(Result__);
			{_,Result__} -> Result__
		end
	end(N,D,T)).

-ifdef(enable_logging).
-define(LOG(Format,Args),
    %% this should also allow any users of the baker-cli to see the debug messages
    io:format(lists:flatten(["~n{~p,~p}: ~p ",Format]),[?MODULE,?LINE,calendar:local_time()] ++ Args)).
-else.
-define(LOG(X,Y), true).
-endif.

-define(ERROR(Format,Args),
    %% this should also allow any users of the baker-cli to see the debug messages
    io:format(lists:flatten(["~n{~p,~p}: ~p ",Format]),[?MODULE,?LINE,calendar:local_time()] ++ Args)).

