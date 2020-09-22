%%% @doc
%%% REST endpoint to manage knowledge collections.
%%% @end

-module(automate_rest_api_services_how_to_enable_new).
-export([init/2]).
-export([ allowed_methods/2
        , options/2
        , is_authorized/2
        , content_types_provided/2
        ]).

-export([ to_json/2
        ]).

-include("./records.hrl").

-record(state, { user_id :: binary() | undefined
               , group_id :: binary()
               , service_id :: binary()
               }).

-spec init(_,_) -> {'cowboy_rest',_,_}.
init(Req, _Opts) ->
    ServiceId = cowboy_req:binding(service_id, Req),
    Qs = cowboy_req:parse_qs(Req),
    GroupId = proplists:get_value(<<"group_id">>, Qs),
    Req1 = automate_rest_api_cors:set_headers(Req),
    {cowboy_rest, Req1
    , #state{ user_id=undefined
            , group_id=GroupId
            , service_id=ServiceId
            }}.

%% CORS
options(Req, State) ->
    {ok, Req, State}.

%% Authentication
-spec allowed_methods(cowboy_req:req(),_) -> {[binary()], cowboy_req:req(),_}.
allowed_methods(Req, State) ->
    {[<<"GET">>, <<"PUT">>, <<"OPTIONS">>], Req, State}.

is_authorized(Req, State=#state{group_id=GroupId}) ->
    Req1 = automate_rest_api_cors:set_headers(Req),
    case cowboy_req:method(Req1) of
        %% Don't do authentication if it's just asking for options
        <<"OPTIONS">> ->
            { true, Req1, State };
        _ ->
            case cowboy_req:header(<<"authorization">>, Req, undefined) of
                undefined ->
                    { {false, <<"Authorization header not found">>} , Req1, State };
                X ->
                    case automate_rest_api_backend:is_valid_token_uid(X) of
                        {true, UserId} ->
                            case GroupId of
                                G when is_binary(G) ->
                                    case automate_storage:is_allowed_to_write_in_group({user, UserId}, GroupId) of
                                        true ->
                                            { true, Req1, State#state{user_id=UserId} };
                                        false ->
                                            { { false, <<"Unauthorized to create a service here">>}, Req1, State }
                                    end
                            end;
                        false ->
                            { { false, <<"Authorization not correct">>}, Req1, State }
                    end
            end
    end.

%% Get handler
content_types_provided(Req, State) ->
    {[{{<<"application">>, <<"json">>, []}, to_json}],
     Req, State}.

-spec to_json(cowboy_req:req(), #state{})
             -> {binary(),cowboy_req:req(), #state{}}.
to_json(Req, State=#state{group_id=GroupId, service_id=ServiceId}) ->
    case get_how_to(GroupId, ServiceId) of
        { ok, HowTo } ->
            Res1 = cowboy_req:delete_resp_header(<<"content-type">>, Req),
            Res2 = cowboy_req:set_resp_header(<<"content-type">>, <<"application/json">>, Res1),

            { jiffy:encode(extend_how_to(HowTo, ServiceId)), Res2, State };
        {error, not_found} ->
            Res1 = cowboy_req:delete_resp_header(<<"content-type">>, Req),
            Res2 = cowboy_req:set_resp_header(<<"content-type">>, <<"application/json">>, Res1),

            %% TODO: Return 404
            { jiffy:encode(#{ <<"success">> => false, <<"message">> => <<"Service not found">> }),
              Res2, State };
        {error, Reason} ->
                Res = cowboy_req:reply(503,
                                       #{ <<"content-type">> => <<"application/json">> },
                                       jiffy:encode(#{ <<"success">> => false
                                                     , <<"error">> => Reason
                                                     }),
                                       Req),
            { stop, Res, State }
    end.

get_how_to(GroupId, ServiceId) ->
    case automate_service_registry:get_service_by_id(ServiceId) of
        E = {error, _} ->
            E;
        {ok, #{ module := Module }} ->
            automate_service_registry_query:get_how_to_enable(Module, #{ group_id => GroupId })
    end.

extend_how_to(HowTo=#{ <<"type">> := <<"form">>
                     , <<"connection_id">> := ConnectionId
                     }, ServiceId) ->
    Restructured = HowTo#{ <<"metadata">> => #{ <<"service_id">> => ServiceId
                                              , <<"connection_id">> => ConnectionId
                                              } },
    maps:remove(<<"connection_id">>, Restructured);

extend_how_to(HowTo=#{ <<"type">> := <<"message">>
                     , <<"connection_id">> := ConnectionId }, ServiceId) ->
    Restructured = HowTo#{ <<"metadata">> => #{ <<"service_id">> => ServiceId
                                              , <<"connection_id">> => ConnectionId
                                              } },
    maps:remove(<<"connection_id">>, Restructured);

extend_how_to(HowTo=#{ <<"type">> := <<"form">> }, ServiceId) ->
    HowTo#{ <<"metadata">> => #{ <<"service_id">> => ServiceId } };

extend_how_to(HowTo=#{ <<"type">> := <<"message">> }, ServiceId) ->
    HowTo#{ <<"metadata">> => #{ <<"service_id">> => ServiceId } };

extend_how_to(HowTo=#{ <<"type">> := <<"direct">> }, ServiceId) ->
    HowTo#{ <<"metadata">> => #{ <<"service_id">> => ServiceId } };

extend_how_to(HowTo, _ServiceId) ->
    HowTo.