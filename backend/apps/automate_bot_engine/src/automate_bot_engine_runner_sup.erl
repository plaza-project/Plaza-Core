%%%-------------------------------------------------------------------
%% @doc automate_bot_engine supervisor for each task being run
%%      (also the one that spawns them).
%% @end
%%%-------------------------------------------------------------------

-module(automate_bot_engine_runner_sup).

-behaviour(supervisor).

%% API
-export([start_link/0
        , start/1
        ]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).
-include("../../automate_common_types/src/definitions.hrl").

%%====================================================================
%% API functions
%%====================================================================
start(ProgramId) ->
    supervisor:start_child(?SERVER, [ProgramId]),
    ok.

start_link() ->
    automate_stats:add_metric(counter, automate_bot_engine_cycles, <<"Automate bot engine cycles.">>,
                              [program_id]),

    Result = supervisor:start_link({local, ?SERVER}, ?MODULE, []),
    ok = start_running_programs(),
    Result.


%%====================================================================
%% Supervisor callbacks
%%====================================================================



%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
    {ok, { {simple_one_for_one, ?AUTOMATE_SUPERVISOR_INTENSITY, ?AUTOMATE_SUPERVISOR_PERIOD},
           [ #{ id => automate_bot_engine_runner
              , start => {automate_bot_engine_runner, start_link, []}
              , restart => permanent
              , shutdown => 2000
              , type => worker
              , modules => [automate_bot_engine_runner]
              }
           ]} }.

%%====================================================================
%% Internal functions
%%====================================================================
start_running_programs() ->
    {ok, Ids} = automate_storage:dirty_list_running_programs(),
    lists:foreach(fun(ProgramId) ->
                          ok = start(ProgramId)
                  end, Ids),
    ok.
