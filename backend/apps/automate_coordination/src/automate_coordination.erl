%%%-------------------------------------------------------------------
%% @doc automate_coordination top level API
%% @end
%%%-------------------------------------------------------------------

-module(automate_coordination).

%% Module API
-export([run_task_not_parallel/2]).

%% Application callbacks
-export([start_link/0]).
-define(BACKEND, automate_coordination_mnesia_backend).
-define(UTILS, automate_coordination_utils).
%%====================================================================
%% API
%%====================================================================
start_link() ->
    ?BACKEND:start_link().

-spec run_task_not_parallel(function(), any()) -> {started, pid()}
                                                      | {already_running, pid()}
                                                      | {error, could_not_start}.
run_task_not_parallel(Function, Id) ->
    Parent = self(),
    %% Process prepared for continuation
    RunnerPid = spawn(fun() -> waiter(Parent, Function) end),

    Result = case ?BACKEND:run_on_process_if_not_started(Id, RunnerPid) of
                 {ok, not_run_used_pid} ->
                     RunnerPid ! continue,
                     {ok, RunnerPid};
                 {ok, is_running, Pid, Node} ->
                     %% TODO: Change this way of checking alive process into
                     %% something reactive, so that if a node is restarted new
                     %% processes cannot be mistaken for old ones.
                     case ?UTILS:is_process_alive(Pid, Node) of
                         false -> %% Stopped
                             case ?BACKEND:run_on_process_if_not_started_or_pid(Id, RunnerPid, Pid) of
                                 {ok, not_run_used_pid} ->
                                     RunnerPid ! continue,
                                     {ok, RunnerPid};
                                 {ok, is_running, Pid, Node} ->
                                     erlang:error("Disqualified PID returned");
                                 {ok, is_running, Pid2, Node2} ->
                                     case ?UTILS:is_process_alive(Pid2, Node2) of
                                         false ->
                                             {error, could_not_start};
                                         true ->
                                             RunnerPid ! cancel,
                                             {ok, Pid2}
                                     end
                             end;
                         true ->
                             RunnerPid ! cancel,
                             {ok, Pid}
                     end
             end,
    case Result of
        {ok, RunnerPid} ->
            {started, RunnerPid};
        {ok, NewPid} ->
            {already_running, NewPid};
        X ->
            X
    end.

%%====================================================================
%% Internal functions
%%====================================================================
waiter(Parent, Function) ->
    receive
        continue ->
            Function();
        cancel ->
            ok;
        Msg ->
            waiter(Parent, Function)
    end.
