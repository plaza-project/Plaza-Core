%%%-------------------------------------------------------------------
%% @doc automate_template_engine APP API
%% @end
%%%-------------------------------------------------------------------

-module(automate_template_engine_app).

-behaviour(application).

%% Application callbacks
-export([start/0, start/2, stop/1]).

%%====================================================================
%% API
%%====================================================================
start() ->
    automate_template_engine_sup:start_link().

start(_StartType, _StartArgs) ->
    start().

%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================
