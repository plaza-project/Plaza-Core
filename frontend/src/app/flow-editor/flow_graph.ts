import { FlowBlockData, Position2D } from "./flow_block";

export interface FlowGraphEdge {
    from: {id: string, output_index: number},
    to: {id: string, input_index: number},
};

export interface FlowGraphNode {
    data: FlowBlockData,
    position: Position2D,
    container_id?: string | null,
};

export interface FlowGraph {
    nodes: { [key: string]: FlowGraphNode },
    edges: FlowGraphEdge[],
};

// Compiled graph
export interface CompiledConstantArg {
    type: 'constant',
    value: any,
};

export interface CompiledVariableArg {
    type: 'variable' | 'list',
    value: any,
};

export type MonitorExpectedValue = CompiledConstantArg;

export interface CompiledBlockArgMonitorDict {
    monitor_id: {
        from_service: string,
    },
    monitor_expected_value: MonitorExpectedValue | 'any_value';
    key: "utc_time" | "utc_date";
    save_to?: {
        type: 'variable',
        value: string,
    }
}

export interface CompiledBlockArgCallServiceDict {
    service_id: string,
    service_action: string,
    service_call_values: CompiledBlockArgList,
}

export interface CompiledBlockArgBlock {
    type: 'block',
    value: CompiledBlock[]
}

interface CompiledBlockServiceCallSelectorArgs {
    key: string,
    subkey?: { type: 'argument', index: number },
};

export type CompiledBlockArg = CompiledBlockArgBlock | CompiledConstantArg | CompiledVariableArg;

export type CompiledBlockArgList = CompiledBlockArg[];

export type CompiledBlockType = "wait_for_monitor"
    | "control_wait_for_next_value"
    | "control_if_else"
    | "operator_and" | "operator_equals" | "operator_lt" | "operator_gt"
    | "operator_add" | "operator_modulo"
    | "flow_last_value"
    | "data_setvariableto" | "data_variable"
    | "command_call_service"
    | "control_wait"
    | "logging_add_log" | "flow_get_thread_id"
    | "jump_to_position"
    | "jump_to_block"
    | "op_fork_execution"
    | "trigger_when_all_completed"
    | "trigger_when_first_completed"
    | "op_preload_getter"
    | "data_lengthoflist" | "data_deleteoflist" | "data_addtolist"

// Signal-only
    | "on_data_variable_update"
    | "op_on_block_run"

// Not found on executable stage, will be removed in link phase
    | "jump_point"

// Operations should not appear on a properly compiled AST
    | "trigger_when_all_completed" | "trigger_when_first_completed"
    | "trigger_on_signal" | "trigger_when_all_true"
    ;
export type CompiledBlockArgs
    = CompiledBlockArgMonitorDict
    | CompiledBlockArgCallServiceDict
    | CompiledBlockArgList
    | CompiledBlockServiceCallSelectorArgs
;

export interface ContentBlock {
    contents: (CompiledBlock | ContentBlock)[],
};

export interface CompiledBlock {
    id?: string,
    type: CompiledBlockType,
    args?: CompiledBlockArgs,
    contents?: (CompiledBlock | ContentBlock)[],
    report_state?: boolean,
};

export type CompiledFlowGraph = CompiledBlock[];
