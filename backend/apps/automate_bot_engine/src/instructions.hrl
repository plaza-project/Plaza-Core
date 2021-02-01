-include("operation_instructions.hrl").

%%%% Instruction map entry names
-define(TYPE, <<"type">>).
-define(ARGUMENTS, <<"args">>).
-define(CONTENTS, <<"contents">>).
-define(BLOCK_ID, <<"id">>).
-define(VALUE, <<"value">>).
-define(TEMPLATE_NAME_TYPE, <<"constant">>).
-define(REPORT_STATE, <<"report_state">>).

%%%% Variables
-define(VARIABLE_BLOCK, <<"block">>).
-define(VARIABLE_CONSTANT, <<"constant">>).
-define(VARIABLE_VARIABLE, <<"variable">>).
-define(VARIABLE_LIST, <<"list">>).

%%%% Signal types
-define(SIGNAL_PROGRAM_TICK, tick).

%% Custom signals
-define(SIGNAL_PROGRAM_CUSTOM, <<"automate_on_custom_signal">>). % Listener
-define(COMMAND_CUSTOM_SIGNAL, <<"automate_trigger_custom_signal">>). % Caller

%%%% Operation parameters
-ifdef(NOTEST).
-define(MILLIS_PER_TICK, 100).
-else.
-define(MILLIS_PER_TICK, 1).
-endif.


%%%% Monitors
%% Values
-define(WAIT_FOR_MONITOR, <<"wait_for_monitor">>).
-define(WAIT_FOR_MONITOR_COMMAND, ?WAIT_FOR_MONITOR).
-define(TRIGGERED_BY_MONITOR, triggered_by_monitor).
-define(MONITOR_ANY_VALUE, <<"any_value">>).

%% Fields
-define(MONITOR_ID, <<"monitor_id">>).
-define(MONITOR_EXPECTED_VALUE, <<"monitor_expected_value">>).
-define(MONITOR_SAVE_VALUE_TO, <<"monitor_save_value_to">>).
-define(MONITOR_KEY, <<"key">>).
-define(FROM_SERVICE, <<"from_service">>).

%%%% Services
-define(SERVICE_ID, <<"service_id">>).
-define(SERVICE_CALL_VALUES, <<"service_call_values">>).
-define(SERVICE_ACTION, <<"service_action">>).

-define(LAST_BRIDGE_VALUES, <<"__last_bridge_values__">>).
-define(UI_TRIGGER_VALUES, <<"__ui_trigger_values">>).
-define(UI_TRIGGER_CONNECTION, <<"connection">>).
-define(UI_TRIGGER_DATA, <<"ui_data">>).

%%%% Special data
-define(LIST_FILL, null).
