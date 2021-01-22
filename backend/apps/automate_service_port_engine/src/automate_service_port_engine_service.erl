%%%-------------------------------------------------------------------
%% @doc Timekeeping service main module.
%% @end
%%%-------------------------------------------------------------------

-module(automate_service_port_engine_service).

%% Service API
-export([ start_link/0
        , is_enabled_for_user/2
        , get_how_to_enable/2
        , listen_service/3
        , call/5
        , send_registration_data/4
        ]).

-define(BACKEND, automate_service_port_engine_mnesia_backend).
-include("../../automate_bot_engine/src/program_records.hrl").
-include("./records.hrl").

%%====================================================================
%% Service API
%%====================================================================

%% No need to initialize service
start_link() ->
    ignore.

-spec listen_service(owner_id(), {binary() | undefined, binary() | undefined}, [binary(), ...]) -> ok | {error, no_valid_connection}.
listen_service(Owner, {Key, SubKey}, [ServicePortId]) ->
    case get_connection(Owner, ServicePortId, [{Key, SubKey}]) of
        {ok, ConnectionId} ->
            {ok, #user_to_bridge_connection_entry{channel_id=ChannelId}} = ?BACKEND:get_connection_by_id(ConnectionId),
            automate_channel_engine:listen_channel(ChannelId, {Key, SubKey});
        {error, not_found} ->
            {error, no_valid_connection}
    end.

-spec call(binary(), any(), #program_thread{}, owner_id(), _) -> {ok, #program_thread{}, any()} | {error, no_connection} | {error, {failed, _}} | {error, timeout} | {error, {error_getting_resource, _}}.
call(FunctionId, Values, Thread=#program_thread{program_id=ProgramId}, Owner, [ServicePortId]) ->
    LastMonitorValue = case automate_bot_engine_variables:get_last_bridge_value(Thread, ServicePortId) of
                           {ok, Value} -> Value;
                           {error, not_found} -> null
                       end,

    ConnectionId = case automate_bot_engine_variables:get_thread_context(Thread) of
                       { ok, #{ bridge_connection := #{ ServicePortId := ContextConnectionId } } } ->
                           ContextConnectionId;
                       _ ->
                           {ok, BlockInfo} = ?BACKEND:get_block_definition(ServicePortId, FunctionId),
                           try get_block_resource(BlockInfo, Values) of
                               Resources ->
                                   case get_connection(Owner, ServicePortId, Resources) of
                                       {ok, AvailableConnection} ->
                                           AvailableConnection
                                   end
                           catch ErrorNS:Error:StackTrace ->
                                   automate_logging:log_platform(error, ErrorNS, Error, StackTrace),
                                   {error, {error_getting_resource, {ErrorNS, Error, StackTrace}}}
                           end
                   end,

    case automate_service_port_engine:call_service_port(
           ServicePortId,
           FunctionId,
           Values,
           ConnectionId,
           #{ <<"last_monitor_value">> => LastMonitorValue}) of
        {ok, #{ <<"result">> := Result }} ->
            ok = automate_storage:mark_successful_call_to_bridge(ProgramId, ServicePortId),
            {ok, Thread, Result};
        {ok, #{ <<"success">> := false, <<"error">> := Reason }} ->
            ok = automate_storage:mark_failed_call_to_bridge(ProgramId, ServicePortId),
            {error, {failed, Reason}};
        {ok, #{ <<"success">> := false }} ->
            ok = automate_storage:mark_failed_call_to_bridge(ProgramId, ServicePortId),
            {error, {failed, undefined}};
        {error, no_response} ->
            ok = automate_storage:mark_failed_call_to_bridge(ProgramId, ServicePortId),
            {error, timeout};
        {error, Reason} ->
            ok = automate_storage:mark_failed_call_to_bridge(ProgramId, ServicePortId),
            {error, Reason}
    end.

%% Is enabled for all users
is_enabled_for_user(_Owner, _Params) ->
    {ok, true}.

%% No need to enable service
-spec get_how_to_enable(owner_id(), [binary()]) -> {ok, map()} | {error, not_found}.
get_how_to_enable(Owner, [ServicePortId]) ->
    {ok, TemporaryConnectionId} = ?BACKEND:gen_pending_connection(ServicePortId, Owner),
    case automate_service_port_engine:get_how_to_enable(ServicePortId, TemporaryConnectionId) of
        {error, Err} ->
            {error, Err};
        {ok, Response} ->
            case Response of
                #{ <<"result">> := null } ->
                    {ok, #{ <<"type">> => <<"direct">> } };
                #{ <<"result">> := Result } ->
                    {ok, Result#{ <<"connection_id">> => TemporaryConnectionId }};
                _ ->
                    {ok, #{ <<"type">> => <<"direct">> } }

            end
    end.

-spec send_registration_data(owner_id(), any(), [binary()], map()) -> {ok, any()}.
send_registration_data(Owner, RegistrationData, [ServicePortId], Properties) ->
    ConnectionId = case Properties of
                       #{ <<"connection_id">> := ConnId } when is_binary(ConnId) -> ConnId;
                       _ ->
                           {ok, TemporaryConnectionId} = ?BACKEND:gen_pending_connection(ServicePortId, Owner),
                           TemporaryConnectionId
                   end,

    {ok, Result} = automate_service_port_engine:send_registration_data(ServicePortId, RegistrationData, ConnectionId),
    PassedResult = case Result of
                       #{ <<"success">> := true } ->
                           Name = get_name_from_result(Result),
                           ok = ?BACKEND:establish_connection(ServicePortId, Owner, ConnectionId, Name),
                           Result;

                       #{ <<"success">> := false, <<"error">> := <<"No registerer available">> } ->
                           %% For compatibility with programaker-bridge library before connections
                           %% where introduced.
                           Name = get_name_from_result(Result),
                           ok = ?BACKEND:establish_connection(ServicePortId, Owner, ConnectionId, Name),
                           Result#{ <<"success">> => true
                                  , <<"error">> => null
                                  };

                       _ ->
                           Result
         end,
    {ok, PassedResult}.

get_name_from_result(#{ <<"data">> := #{ <<"name">> := Name } }) ->
    Name;
get_name_from_result(_) ->
    undefined.


%%====================================================================
%% Internal
%%====================================================================
-spec get_connection(Owner :: owner_id(), ServicePortId :: binary(), [{ binary() | undefined, binary() | undefined }])
                    -> {ok, binary()} | {error, not_found}.
get_connection(Owner, ServicePortId, Resources) ->
    case automate_service_port_engine:internal_user_id_to_connection_id(Owner, ServicePortId) of
        {ok, DefaultConnectionId} ->
            {ok, DefaultConnectionId};
        {error, not_found} ->
            {ok, Shares} = automate_service_port_engine:get_resources_shared_with_on_bridge(Owner, ServicePortId),
            %% TODO: For usign blocks that require multiple resources it'd be necessary to consider
            %% all resources shared for each connection. Instead of each share entry separately.
            MatchingConnections = lists:filter(fun(#bridge_resource_share_entry{ resource=_SharedResource
                                                                               , value=SharedResourceValue
                                                                               }) ->
                                                       lists:all(fun({ _Key, ResourceValue }) ->
                                                                         ResourceValue == SharedResourceValue
                                                                 end, Resources)
                                               end, Shares),
            case MatchingConnections of
                [#bridge_resource_share_entry{ connection_id=SharedConnectionId } | _] ->
                    {ok, SharedConnectionId};
                [] ->
                    {error, not_found}
            end
    end.

-spec get_block_resource(BlockInfo :: #service_port_block{}, Values :: [ any() ])
                        -> [{ binary(), binary()}].
get_block_resource(#service_port_block{ arguments=Args, save_to=SaveTo }, Values) ->
    SaveToIndex = case SaveTo of
                      #{ <<"type">> := <<"argument">>
                       , <<"index">> := Idx
                       } ->
                          Idx;
                      _ ->
                          -1
                  end,
    get_block_resource_aux(Args, Values, SaveToIndex, 0, []).

get_block_resource_aux([], [], _, _, Acc) ->
    Acc;
get_block_resource_aux([ _ | TArg], Values, SaveToIndex, CurrentIndex, Acc) when SaveToIndex == CurrentIndex ->
    get_block_resource_aux(TArg, Values, SaveToIndex, CurrentIndex + 1, Acc);
get_block_resource_aux([ #service_port_block_collection_argument{ name=Name } | TArg ], [ Value | TValue ], SaveToIndex, CurrentIndex, Acc) ->
    get_block_resource_aux(TArg, TValue, SaveToIndex, CurrentIndex + 1, [{Name, Value} | Acc]);
get_block_resource_aux([ _ | TArg ], [ _ | TValue ], SaveToIndex, CurrentIndex, Acc) ->
    get_block_resource_aux(TArg, TValue, SaveToIndex, CurrentIndex + 1, Acc);
get_block_resource_aux(_, _, _, _, Acc)->
    %% TArgs and TValues don't have the same length.
    %% One of them has stopped, so return the collected result.
    Acc.
