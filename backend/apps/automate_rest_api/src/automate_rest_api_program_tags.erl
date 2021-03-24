%%% @doc
%%% REST endpoint to manage knowledge collections.
%%% @end

-module(automate_rest_api_program_tags).
-export([init/2]).
-export([ allowed_methods/2
        , options/2
        , is_authorized/2
        , content_types_provided/2
        , content_types_accepted/2
        , resource_exists/2
        ]).

-export([ accept_tags_update/2
        , to_json/2
        ]).

-define(UTILS, automate_rest_api_utils).
-include("./records.hrl").

-record(state, { program_id :: binary() }).

-spec init(_,_) -> {'cowboy_rest',_,_}.
init(Req, _Opts) ->
    ProgramId = cowboy_req:binding(program_id, Req),
    {cowboy_rest, Req
    , #state{ program_id=ProgramId }}.

resource_exists(Req, State) ->
    case cowboy_req:method(Req) of
        <<"POST">> ->
            { false, Req, State };
        _ ->
            { true, Req, State}
    end.

%% CORS
options(Req, State) ->
    Req1 = automate_rest_api_cors:set_headers(Req),
    {ok, Req1, State}.

%% Authentication
-spec allowed_methods(cowboy_req:req(),_) -> {[binary()], cowboy_req:req(),_}.
allowed_methods(Req, State) ->
    {[<<"GET">>, <<"POST">>, <<"OPTIONS">>], Req, State}.

is_authorized(Req, State=#state{program_id=ProgramId}) ->
    Req1 = automate_rest_api_cors:set_headers(Req),
    case cowboy_req:method(Req1) of
        %% Don't do authentication if it's just asking for options
        <<"OPTIONS">> ->
            { true, Req1, State };
        Method ->
            case cowboy_req:header(<<"authorization">>, Req, undefined) of
                undefined ->
                    { {false, <<"Authorization header not found">>} , Req1, State };
                X ->
                    {Action, Scope} = case Method of
                                          <<"GET">> -> {read_program, {read_program, ProgramId}};
                                          _ -> {edit_program, {edit_program, ProgramId}}
                            end,
                    case automate_rest_api_backend:is_valid_token_uid(X, Scope) of
                        {true, UserId} ->
                            case automate_storage:is_user_allowed({user, UserId}, ProgramId, Action) of
                                {ok, true} ->
                                    { true, Req1, State };
                                {ok, false} ->
                                    { { false, <<"Unauthorized">>}, Req1, State }
                            end;
                        false ->
                            { { false, <<"Authorization not correct">>}, Req1, State }
                    end
            end
    end.

%% POST handler
content_types_accepted(Req, State) ->
    {[{{<<"application">>, <<"json">>, []}, accept_tags_update}],
     Req, State}.

-spec accept_tags_update(_, #state{}) -> {boolean(),_,#state{}}.
accept_tags_update(Req, State=#state{program_id=ProgramId }) ->
    {ok, Body, _} = ?UTILS:read_body(Req),
    #{<<"tags">> := Tags } = jiffy:decode(Body, [return_maps]),

    case automate_storage:register_program_tags(ProgramId, Tags) of
        ok ->

            Output = jiffy:encode(#{ <<"success">> => true
                                   }),

            Res1 = cowboy_req:set_resp_body(Output, Req),
            Res2 = cowboy_req:delete_resp_header(<<"content-type">>, Res1),
            Res3 = cowboy_req:set_resp_header(<<"content-type">>, <<"application/json">>, Res2),

            { true, Res3, State };
        {error, _} ->
            Output = jiffy:encode(#{ <<"success">> => false
                                   }),

            Res1 = cowboy_req:set_resp_body(Output, Req),
            Res2 = cowboy_req:delete_resp_header(<<"content-type">>, Res1),
            Res3 = cowboy_req:set_resp_header(<<"content-type">>, <<"application/json">>, Res2),

            { false, Res3, State }
    end.

%% GET handler
content_types_provided(Req, State) ->
    {[{{<<"application">>, <<"json">>, []}, to_json}],
     Req, State}.

-spec to_json(cowboy_req:req(), #state{}) -> {binary(),cowboy_req:req(), #state{}}.
to_json(Req, State=#state{program_id=ProgramId}) ->
    case automate_storage:get_tags_program_from_id(ProgramId) of
        { ok, Tags } ->
            Output = jiffy:encode(Tags),
            Res1 = cowboy_req:delete_resp_header(<<"content-type">>, Req),
            Res2 = cowboy_req:set_resp_header(<<"content-type">>, <<"application/json">>, Res1),

            { Output, Res2, State }
    end.
