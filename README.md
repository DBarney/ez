### Play

This application really doesn't do anything except server as a repo for commonly used functions that I use for:
- eunit testing
- logging, but not really anymore
- makeing fprof easier to use
- testing the speed of a function a repeated number of times

## Eunit Testing structure

The eunit structure building macros that I have built allow to build eunit tests very consisely. For example this is what an eunit test might look like normally:

```

private_tests_()->
[{
	"this is a description",
	fun() ->
		meck:new(fake_mod,[]),
		meck:expect(fake_mod,do_stuff,fun(Param)-> {ok,Param} end),

		Result = fake_mod:do_stuff(testing),

		assertMatch({ok,testing},Result),

		meck:unload(fake_mod)
	end
}]

```

and this is the same eunit test built with my macro


```

private_tests_()->
Tests = [
	{"this is a description"
	{fake_mod,do_stuff,[testing]},
	[{fake_mod,
		[{dostuff,fun(Param) -> {ok,Param} end}]}],
	{ok,testing}}

],

?BUILD_TESTS(Tests).

```

Its a little more consise, but a ton more consise when dealing with mecking the same module over and over again.
Mostly because it can be abstracted away indie of a ?Macro.

The general structure of the tuple list is as follows:

```

### Standard
Tests() :: [Test() | Test()].
Test()	:: {Call :: Call(), Mecks :: Mecks(), Check :: Check()}

Check()	:: Fun :: fun() -> (true | false)
		|  Any :: any()

Call()	:: { Mod :: atom(), Fun :: atom(), Args :: [ Arg :: any() | Arg :: any()]}
		|  Function :: fun() -> any()
		|  {fun(Arg :: any(),Arg :: any()), [Arg :: any() | Arg :: any()]}
Mecks() :: [Meck :: Meck() | Meck :: Meck()]
Meck()	:: {Mod :: atom(), Meck_list :: [Meck_fun :: Meck_funs() | Meck_fun :: Meck_funs() ]}
		|  {Mod :: atom(), Opts :: [any() | any()], [Meck_fun :: Meck_funs() | Meck_fun :: Meck_funs() ]}
Meck_funs()	:: {Fun :: atom(), Fun_list :: [Fun :: Meck_fun() | Fun :: Meck_fun()]}
Meck_fun()	:: {Name :: atom(), Fun :: fun(Elem :: any()) -> any()}


### Extended
			|  {Name :: atom(), Patterns :: {all, Arity :: Integer(), Behaviors :: [Behavior :: Behavior() | Behavior :: Behavior()]}}
			|  {Name :: atom(), Matches :: [Match :: Match() | Match :: Match()]}
Match()	:: {Args :: [Arg :: any() | Arg :: any()], Behaviors :: [Behavior :: Behavior() | Behavior :: Behavior()]}
Behavior()	:: {push,Key :: atom(), Value :: any()}
			|  {pop,Key :: atom()}
			|  {ret,Value :: any()}

```



Lots of options there, for the most part I would stick with using the standard mecking behavior, as the extened really has only been used a few time. mostly when testing out functions that need to return differently even though the same parameters are passed. (i.e fun gen_tcp:recv/2)


Also this is how I would reccomend that the test be structured so that you don't end up with a large block of brackets at the end of the structure that may or may not be correct.

```
	[{
		"Transfer Encoding Chunked identifies the end of the transfer if received from the server"
		,{baker_http_proxy,proxy,[Server,Client,chunked,<<"0\r\n\r\n">>,unknown]} # always on one line
		,[{fake_trans, # always on one line
			[{setopts,fun(_,_)-> ok end} # can be on one line if fun only has 1 caluse and is simple
			,{send,fun ## needs to be split across multiple lines and indented twice becuase of multiple clauses
					(client,<<"0\r\n">>)-> ok;
					(client,<<"\r\n">>)-> ok end}]}]
		,{extra,<<>>}} # one line unless its a fun, if its a fun the same rules apply as the funs in the meck area.
	],
```

so in recap:
- Funs
	- can be one one line if the are small and have one clause `fun() -> ok end
	- need to be split across multiple lines if larger or have multiple clauses

```
	fun
		(a) -> ok;
		(_) -> bad end

	or 

	fun(A)->
		case A of
		a -> ok;
		_ -> end
	end end

```

	- funs also should try to keep the last `end` on the same line as the list line of code so:
		- *this is only for the structure of these tests*

```
	good
	fun() -> ok end

	good
	fun()->
		case true of
			true
		end end

	bad
	fun() -> ok
	end
```
- Lists
	- should e structured so that all elements in the list are at the same indentation
		- unless
			- there is a sublist with multiple elements, then the sublist is indented
			- or the list is small and does not have a lot of elements

```
	[a,b,c]
	
	[{a,true}
	,{b,true}
	,{c,true}]
	
	[{a,true}
	,{b,
		[{test,me}
		,{once,again}]
	,{c,true}}]

	List = 	[{a,true}
			,{b,true}
			,{c,true}],
```
