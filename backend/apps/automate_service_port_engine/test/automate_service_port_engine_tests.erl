%%% @doc
%%% Automate service port custom blocks management tests.
%%% @end

-module(automate_service_port_engine_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../src/records.hrl").

%% Test data
-define(APPLICATION, automate_service_port_engine).
-define(TEST_NODES, [node()]).
-define(BACKEND, automate_service_port_engine_mnesia_backend).
-define(TEST_ID_PREFIX, "automate_service_port_engine_custom_blocks_tests").
-define(RECEIVE_TIMEOUT, 100).

%%====================================================================
%% Test API
%%====================================================================

session_manager_test_() ->
    {setup
    , fun setup/0
    , fun stop/1
    , fun tests/1
    }.

%% @doc App infrastructure setup.
%% @end
setup() ->
    NodeName = node(),

    %% Use a custom node name to avoid overwriting the actual databases
    net_kernel:start([testing, shortnames]),

    {ok, _Pid} = application:ensure_all_started(?APPLICATION),

    {NodeName}.

%% @doc App infrastructure teardown.
%% @end
stop({NodeName}) ->
    %% ?BACKEND:uninstall(),
    ok = application:stop(?APPLICATION),

    ok.

tests(_SetupResult) ->
    %% Custom blocks
    [ { "[Service Port - Custom blocks] Owned private blocks appear"
      , fun owned_private_blocks_appear/0
      }
    , { "[Service Port - Custom blocks] Non-owned private blocks don't appear"
      , fun non_owned_private_blocks_dont_appear/0
      }
    , { "[Service Port - Custom blocks] Owned public blocks appear"
      , fun owned_public_blocks_appear/0
      }
    , { "[Service Port - Custom blocks] Non-owned public blocks appear"
      , fun non_owned_public_blocks_appear/0
      }
    , { "[Service Port - Custom blocks] Deleting a bridge deletes its custom blocks"
      , fun owned_delete_bridge_blocks/0
      }
      %% Notification routing
    , { "[Service port - Notifications] Route notifications targeted to owner"
      , fun route_notification_targeted_to_owner/0
      }
    , { "[Service port - Notifications] Route notifications targeted to owner on public"
      , fun route_notification_targeted_to_owner_on_public/0
      }
    , { "[Service port - Notifications] Route notifications targeted to non-owner on public"
      , fun route_notification_targeted_to_non_owner_on_public/0
      }
    , { "[Service port - Notifications] Route notifications to all users on public"
      , fun route_notification_targeted_to_all_users_on_public/0
      }
      %% Configuration
    , { "[Service port - Configuration] A public bridge can be later set to private"
      , fun set_public_bridge_to_private/0
      }
    , { "[Service port - Configuration] A private bridge can be later set to public"
      , fun set_private_bridge_to_public/0
      }
    ].


%%====================================================================
%% Custom block tests
%%====================================================================
owned_private_blocks_appear() ->
    OwnerUserId = <<?TEST_ID_PREFIX, "-test-1-owner">>,
    ServicePortName = <<?TEST_ID_PREFIX, "-test-1-service-port">>,
    {ok, ServicePortId} = ?APPLICATION:create_service_port({user, OwnerUserId}, ServicePortName),

    Configuration = #{ <<"is_public">> => false
                     , <<"service_name">> => ServicePortName
                     , <<"blocks">> => [ get_test_block() ]
                     },
    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => Configuration
                                                      })),

    ok = establish_connection(ServicePortId, {user, OwnerUserId}),

    {ok, #{ ServicePortId := [CustomBlock] }} = ?APPLICATION:list_custom_blocks({user, OwnerUserId}),

    check_test_block(CustomBlock).


non_owned_private_blocks_dont_appear() ->
    OwnerUserId = <<?TEST_ID_PREFIX, "-test-2-owner">>,
    RequesterUserId = <<?TEST_ID_PREFIX, "-test-2-requester">>,
    ServicePortName = <<?TEST_ID_PREFIX, "-test-2-service-port">>,
    {ok, ServicePortId} = ?APPLICATION:create_service_port({user, OwnerUserId}, ServicePortName),

    Configuration = #{ <<"is_public">> => false
                     , <<"service_name">> => ServicePortName
                     , <<"blocks">> => [ get_test_block() ]
                     },
    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => Configuration
                                                      })),

    case ?BACKEND:gen_pending_connection(ServicePortId, {user, RequesterUserId}) of
        {ok, ConnectionId} ->
            %% TODO This connection should *not* be possible
            ?BACKEND:establish_connection(ServicePortId, {user, RequesterUserId}, ConnectionId, undefined);
        _ ->
            ok
    end,

    {ok, Results} = ?APPLICATION:list_custom_blocks({user, RequesterUserId}),
    ?assertEqual(#{}, Results).


owned_public_blocks_appear() ->
    OwnerUserId = <<?TEST_ID_PREFIX, "-test-3-owner">>,
    ServicePortName = <<?TEST_ID_PREFIX, "-test-3-service-port">>,
    {ok, ServicePortId} = ?APPLICATION:create_service_port({user, OwnerUserId}, ServicePortName),

    Configuration = #{ <<"is_public">> => true
                     , <<"service_name">> => ServicePortName
                     , <<"blocks">> => [ get_test_block() ]
                     },
    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => Configuration
                                                      })),

    ok = establish_connection(ServicePortId, {user, OwnerUserId}),

    {ok, #{ ServicePortId := [CustomBlock] }} = ?APPLICATION:list_custom_blocks({user, OwnerUserId}),

    check_test_block(CustomBlock).

non_owned_public_blocks_appear() ->
    OwnerUserId = <<?TEST_ID_PREFIX, "-test-4-owner">>,
    RequesterUserId = <<?TEST_ID_PREFIX, "-test-4-requester">>,
    ServicePortName = <<?TEST_ID_PREFIX, "-test-4-service-port">>,
    {ok, ServicePortId} = ?APPLICATION:create_service_port({user, OwnerUserId}, ServicePortName),

    Configuration = #{ <<"is_public">> => true
                     , <<"service_name">> => ServicePortName
                     , <<"blocks">> => [ get_test_block() ]
                     },
    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => Configuration
                                                      })),

    ok = establish_connection(ServicePortId, {user, RequesterUserId}),

    {ok, #{ ServicePortId := [CustomBlock] }} = ?APPLICATION:list_custom_blocks({user, RequesterUserId}),

    check_test_block(CustomBlock).

owned_delete_bridge_blocks() ->
    OwnerUserId = <<?TEST_ID_PREFIX, "-test-5-owner">>,
    ServicePortName = <<?TEST_ID_PREFIX, "-test-5-service-port">>,
    {ok, BridgeId} = ?APPLICATION:create_service_port({user, OwnerUserId}, ServicePortName),

    Configuration = #{ <<"is_public">> => true
                     , <<"service_name">> => ServicePortName
                     , <<"blocks">> => [ get_test_block() ]
                     },
    ok = ?APPLICATION:from_service_port(BridgeId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => Configuration
                                                      })),

    ok = establish_connection(BridgeId, {user, OwnerUserId}),

    {ok, #{ BridgeId := [CustomBlock] }} = ?APPLICATION:list_custom_blocks({user, OwnerUserId}),
    %% Blocks are created
    check_test_block(CustomBlock),

    {ok, ServiceId} = automate_service_port_engine_mnesia_backend:get_service_id_for_port(BridgeId),
    ?assertMatch({ok, _}, automate_service_registry:get_service_by_id(ServiceId)),

    {ok, ResultsOk} = ?APPLICATION:list_custom_blocks({user, OwnerUserId}),
    ?assertMatch({ok, _}, maps:find(ServiceId, ResultsOk)),
    {ok, BeforeDeleteServices} = automate_service_registry:get_all_services_for_user({user, OwnerUserId}),

    %% Delete bridge
    ok = automate_service_port_engine:delete_bridge({user, OwnerUserId}, BridgeId),

    %% Blocks are destroyed
    {ok, Results} = ?APPLICATION:list_custom_blocks({user, OwnerUserId}),
    ?assertEqual(error, maps:find(ServiceId, Results)),

    %% Service deregistred
    ?assertEqual({error, not_found}, automate_service_port_engine_mnesia_backend:get_service_id_for_port(BridgeId)),
    ?assertEqual({error, not_found}, automate_service_registry:get_service_by_id(ServiceId)),

    {ok, Services} = automate_service_registry:get_all_services_for_user({user, OwnerUserId}),
    ?assertEqual(error, maps:find(ServiceId, Services)).

%%====================================================================
%% Custom block tests - Internal functions
%%====================================================================
-define(Arguments, []).
-define(FunctionName, <<"first_function_name">>).
-define(FunctionId, <<"first_function_id">>).
-define(FunctionMessage, <<"sample message">>).
-define(BlockType, <<"str">>).
-define(BlockResultType, null).
-define(SaveTo, undefined).

get_test_block() ->
    #{ <<"arguments">> => ?Arguments
     , <<"function_name">> => ?FunctionName
     , <<"message">> => ?FunctionMessage
     , <<"id">> => ?FunctionId
     , <<"block_type">> => ?BlockType
     , <<"block_result_type">> => ?BlockResultType
     }.

check_test_block(Block) ->
    ?assertMatch(#service_port_block{ block_id=?FunctionId
                                    , function_name=?FunctionName
                                    , message=?FunctionMessage
                                    , arguments=?Arguments
                                    , block_type=?BlockType
                                    , block_result_type=?BlockResultType
                                    , save_to=?SaveTo
                                    }, Block).
-undef(Arguments).
-undef(FunctionName).
-undef(FunctionId).
-undef(FunctionMessage).
-undef(BlockType).
-undef(BlockResultType).
-undef(SaveTo).

%%====================================================================
%% Notification routing tests
%%====================================================================
route_notification_targeted_to_owner() ->
    OwnerUserId = <<?TEST_ID_PREFIX, "-route-test-1-owner">>,
    TargetUserId = {user, OwnerUserId},
    ServicePortName = <<?TEST_ID_PREFIX, "-route-test-1-service-port">>,
    {ok, ServicePortId} = ?APPLICATION:create_service_port(OwnerUserId, ServicePortName),

    %% Configure service port
    Configuration = #{ <<"is_public">> => false
                     , <<"service_name">> => ServicePortName
                     , <<"blocks">> => [ ]
                     },

    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => Configuration
                                                      })),

    %% Listen on the service port
    {ok, #{ module := Module }} = automate_service_registry:get_service_by_id(ServicePortId),
    {ok, ChannelId } = automate_service_registry_query:get_monitor_id(Module, TargetUserId),
    ok = automate_channel_engine:listen_channel(ChannelId),
    ok = establish_connection(ServicePortId, TargetUserId),

    %% Emit notification
    {ok, ExpectedContent} = emit_notification(ServicePortId, OwnerUserId,
                                              TargetUserId, #{ <<"test">> => 1 }),

    %% Catch notification
    receive {channel_engine, ChannelId, ReceivedMessage} ->
            ?assertEqual(ExpectedContent, ReceivedMessage)
    after ?RECEIVE_TIMEOUT ->
            ct:fail(timeout)
    end.


route_notification_targeted_to_owner_on_public() ->
    OwnerUserId = <<?TEST_ID_PREFIX, "-route-test-2-owner">>,
    TargetUserId = {user, OwnerUserId},
    ServicePortName = <<?TEST_ID_PREFIX, "-route-test-2-service-port">>,
    {ok, ServicePortId} = ?APPLICATION:create_service_port(OwnerUserId, ServicePortName),

    %% Configure service port
    Configuration = #{ <<"is_public">> => true
                     , <<"service_name">> => ServicePortName
                     , <<"blocks">> => [ ]
                     },

    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => Configuration
                                                      })),

    %% Listen on the service port
    {ok, #{ module := Module }} = automate_service_registry:get_service_by_id(ServicePortId),
    {ok, ChannelId } = automate_service_registry_query:get_monitor_id(Module, TargetUserId),
    ok = automate_channel_engine:listen_channel(ChannelId),
    ok = establish_connection(ServicePortId, TargetUserId),

    %% Emit notification
    {ok, ExpectedContent} = emit_notification(ServicePortId, OwnerUserId,
                                              TargetUserId, #{ <<"test">> => 2 }),

    %% Catch notification
    receive {channel_engine, ChannelId, ReceivedMessage} ->
            ?assertEqual(ExpectedContent, ReceivedMessage)
    after ?RECEIVE_TIMEOUT ->
            ct:fail(timeout)
    end.

route_notification_targeted_to_non_owner_on_public() ->
    OwnerUserId = <<?TEST_ID_PREFIX, "-route-test-3-owner">>,
    TargetUserId = {user, <<?TEST_ID_PREFIX, "-route-test-3-NONowner-TARGET">>},
    ServicePortName = <<?TEST_ID_PREFIX, "-route-test-3-service-port">>,
    {ok, ServicePortId} = ?APPLICATION:create_service_port(OwnerUserId, ServicePortName),

    %% Configure service port
    Configuration = #{ <<"is_public">> => true
                     , <<"service_name">> => ServicePortName
                     , <<"blocks">> => [ ]
                     },

    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => Configuration
                                                      })),

    %% Listen on the service port
    {ok, #{ module := Module }} = automate_service_registry:get_service_by_id(ServicePortId),
    {ok, ChannelId } = automate_service_registry_query:get_monitor_id(Module, TargetUserId),
    ok = automate_channel_engine:listen_channel(ChannelId),
    ok = establish_connection(ServicePortId, TargetUserId),

    %% Emit notification
    {ok, ExpectedContent} = emit_notification(ServicePortId, OwnerUserId,
                                              TargetUserId, #{ <<"test">> => 3 }),

    %% Catch notification
    receive {channel_engine, ChannelId, ReceivedMessage} ->
            ?assertEqual(ExpectedContent, ReceivedMessage)
    after ?RECEIVE_TIMEOUT ->
            ct:fail(timeout)
    end.

route_notification_targeted_to_all_users_on_public() ->
    OwnerUserId = <<?TEST_ID_PREFIX, "-route-test-4-owner">>,
    TargetUserId = <<?TEST_ID_PREFIX, "-route-test-4-NONowner-TARGET">>,
    ServicePortName = <<?TEST_ID_PREFIX, "-route-test-4-service-port">>,
    {ok, ServicePortId} = ?APPLICATION:create_service_port(OwnerUserId, ServicePortName),

    %% Configure service port
    Configuration = #{ <<"is_public">> => true
                     , <<"service_name">> => ServicePortName
                     , <<"blocks">> => [ ]
                     },

    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => Configuration
                                                      })),

    %% Listen on the service port for non-owner
    {ok, #{ module := NonOwnerModule }} = automate_service_registry:get_service_by_id(
                                            ServicePortId),
    {ok, NonOwnerChannelId } = automate_service_registry_query:get_monitor_id(
                                 NonOwnerModule, TargetUserId),
    ok = automate_channel_engine:listen_channel(NonOwnerChannelId),

    %% Listen on the service port for owner
    {ok, #{ module := OwnerModule }} = automate_service_registry:get_service_by_id(
                                         ServicePortId),
    {ok, OwnerChannelId } = automate_service_registry_query:get_monitor_id(
                              OwnerModule, OwnerUserId),
    ok = automate_channel_engine:listen_channel(OwnerChannelId),

    %% Emit notification
    {ok, ExpectedContent} = emit_notification(ServicePortId, OwnerUserId,
                                              null, #{ <<"test">> => 4 }),

    %% Get notification twice
    receive {channel_engine, NonOwnerChannelId, NonOwnerReceivedMessage} ->
            ?assertEqual(ExpectedContent, NonOwnerReceivedMessage)
    after ?RECEIVE_TIMEOUT ->
            ct:fail(notif_to_all_users_non_owner_not_received)
    end,
    receive {channel_engine, OwnerChannelId, OwnerReceivedMessage} ->
            ?assertEqual(ExpectedContent, OwnerReceivedMessage)
    after ?RECEIVE_TIMEOUT ->
            ct:fail(notif_to_all_users_owner_not_received)
    end.


%%====================================================================
%% Configuration
%%====================================================================
set_public_bridge_to_private() ->
    OwnerUserId = <<?TEST_ID_PREFIX, "-route-test-5-owner">>,
    TargetUserId = <<?TEST_ID_PREFIX, "-route-test-5-NONowner-TARGET">>,
    ServicePortName = <<?TEST_ID_PREFIX, "-route-test-5-service-port">>,
    {ok, ServicePortId} = ?APPLICATION:create_service_port({user, OwnerUserId}, ServicePortName),

    %% Configure service port
    Configuration = #{ <<"is_public">> => true
                     , <<"service_name">> => ServicePortName
                     , <<"blocks">> => [ ]
                     },

    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => Configuration
                                                      })),
    ?assertMatch({ok, #{ ServicePortId := _ }}, automate_service_registry:get_all_services_for_user({user, TargetUserId})),

    %% Set to private
    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => #{ <<"is_public">> => false
                                                                        , <<"service_name">> => ServicePortName
                                                                        , <<"blocks">> => [ ]
                                                                        }
                                                      })),
    ?assertNotMatch({ok, #{ ServicePortId := _ }}, automate_service_registry:get_all_services_for_user({user, TargetUserId})).



set_private_bridge_to_public() ->
    OwnerUserId = <<?TEST_ID_PREFIX, "-route-test-6-owner">>,
    TargetUserId = <<?TEST_ID_PREFIX, "-route-test-6-NONowner-TARGET">>,
    ServicePortName = <<?TEST_ID_PREFIX, "-route-test-6-service-port">>,
    {ok, ServicePortId} = ?APPLICATION:create_service_port({user, OwnerUserId}, ServicePortName),

    %% Configure service port
    Configuration = #{ <<"is_public">> => false
                     , <<"service_name">> => ServicePortName
                     , <<"blocks">> => [ ]
                     },

    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => Configuration
                                                      })),
    ?assertNotMatch({ok, #{ ServicePortId := _ }}, automate_service_registry:get_all_services_for_user({user, TargetUserId})),

    %% Set to public
    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"CONFIGURATION">>
                                                      , <<"value">> => #{ <<"is_public">> => true
                                                                        , <<"service_name">> => ServicePortName
                                                                        , <<"blocks">> => [ ]
                                                                        }
                                                      })),
    ?assertMatch({ok, #{ ServicePortId := _ }}, automate_service_registry:get_all_services_for_user({user, TargetUserId})).


%%====================================================================
%% Notification routing tests - Internal functions
%%====================================================================
establish_connection(BridgeId, UserId) ->
    {ok, ConnectionId} = ?BACKEND:gen_pending_connection(BridgeId, UserId),
    ok = ?BACKEND:establish_connection(BridgeId, UserId, ConnectionId, <<"test connection">>).

emit_notification(ServicePortId, OwnerUserId, TargetUserId, Content) ->
    Key = binary:list_to_bin(atom_to_list(?MODULE)),
    Value = Content, %% For simplicity

    ToUserId = case TargetUserId of
                   null -> null;
                   _ ->
                       {ok, ConnectionId} = ?APPLICATION:internal_user_id_to_connection_id(TargetUserId,
                                                                                           ServicePortId),
                       ConnectionId
               end,
    ok = ?APPLICATION:from_service_port(ServicePortId, OwnerUserId,
                                        jiffy:encode(#{ <<"type">> => <<"NOTIFICATION">>
                                                      , <<"key">> => Key
                                                      , <<"to_user">> => ToUserId
                                                      , <<"value">> => Value
                                                      , <<"content">> => Content
                                                      })),
    {ok, #{ <<"content">> => Content
          , <<"key">> => Key
          , <<"value">> => Value
          , <<"subkey">> => undefined
          }}.
