import { CompiledBlock, CompiledBlockArg, CompiledBlockArgCallServiceDict, CompiledBlockArgList, CompiledFlowGraph, ContentBlock } from '../../../flow-editor/flow_graph';
import { _link_graph } from '../../../flow-editor/graph_analysis';
const stable_stringify = require('fast-json-stable-stringify');

type _AndOp = ['operator_and', SimpleArrayAstArgument, SimpleArrayAstArgument];
type _EqualsOp = ['operator_equals', SimpleArrayAstArgument, SimpleArrayAstArgument]
    | ['operator_equals', SimpleArrayAstArgument, SimpleArrayAstArgument, SimpleArrayAstArgument];
type _CallServiceOp = ['command_call_service',
                       { service_id: string, service_action: string, service_call_values: SimpleArrayAstArgument[] }];
type _WaitForMonitorOp = ['wait_for_monitor', { monitor_id: { from_service: string }, key: "utc_time" | "utc_date", monitor_expected_value: any }];
type _LastValueOp = ['flow_last_value', string, number | string];
type _IfElseOp = ['control_if_else', SimpleArrayAstArgument, SimpleArrayAstOperation[]];
type _ForkExecOp = ['op_fork_execution', SimpleArrayAstArgument[], SimpleArrayAstOperation[]]

export type SimpleArrayAstArgument = SimpleArrayAstOperation | string | number
export type SimpleArrayAstArgs = _AndOp | _EqualsOp
    | _CallServiceOp
    | _WaitForMonitorOp | _LastValueOp
    | _IfElseOp
    | _ForkExecOp
;

export type SimpleArrayAstOperation = SimpleArrayAstArgs;

export type SimpleArrayAst = SimpleArrayAstOperation[];

const SLOT_OPS = {
    data_variable: 'variable',
    on_data_variable_update: 'variable',
    data_setvariableto: 'variable',

    data_lengthoflist: 'list',
    data_deleteoflist: 'list',
    data_addtolist: 'list',
};

function convert_argument(arg: SimpleArrayAstArgument): CompiledBlockArg {
    if ((typeof arg === 'string') || (typeof arg === 'number')) {
        return {
            type: 'constant',
            value: arg,
        };
    }

    return {
        type: 'block',
        value: [convert_operation(arg)],
    };
}

function convert_ast(ast: SimpleArrayAstOperation[]): CompiledBlock[] {
    const result = [];
    for (let idx = 0; idx < ast.length; idx++) {
        const op = convert_operation(ast[idx]);
        result.push(op);
    }

    return result;
}

function convert_contents(contents: SimpleArrayAstOperation[]): ContentBlock {
    return {
        contents: convert_ast(contents)
    }
}

function convert_operation(op: SimpleArrayAstOperation): CompiledBlock {
    if (op[0] === 'wait_for_monitor') {
        return {
            type: op[0],
            args: op[1],
            contents: [],
        }
    }

    if (op[0] === 'command_call_service') {
        return {
            type: op[0],
            args: {
                service_action: op[1].service_action,
                service_id: op[1].service_id,
                service_call_values: op[1].service_call_values.map(v => convert_argument(v))
            },
            contents: [],
        }
    }

    if (op[0] === 'control_if_else') {
        const contents = (op.slice(2) as SimpleArrayAstOperation[][]).map(v => convert_contents(v));

        if (contents.length < 2) {
            contents.push({ contents: [] });
        }

        return {
            type: op[0],
            args: [ convert_argument(op[1]) ],
            contents: contents,
        }
    }

    if (op[0] === 'op_fork_execution') {
        const contents = (op[2] as SimpleArrayAstOperation[][]).map(v => convert_contents(v));

        if (contents.length < 2) {
            console.warn('Fork (op_fork_execution) with less than two outward paths');
        }

        return {
            type: op[0],
            args: op[1].map(arg => convert_argument(arg)),
            contents: contents,
        }
    }

    if (op[0].startsWith('services.') && (!op[0].startsWith('services.ui.'))) {
        return {
            type: op[0],
            args: {
                key: op[0].split('.').reverse()[0]
            },
        };
    }

    if (typeof op !== 'object') {
        throw new Error(`ASTCompilationError: Expected argument array, found: ${JSON.stringify(op)}. Check for errors on argument nesting`);
    }

    const compiled_args = (op.slice(1) as SimpleArrayAstArgument[]).map(v => convert_argument(v));

    if (SLOT_OPS[op[0]]) {
        compiled_args[0].type = SLOT_OPS[op[0]];
    }

    return {
        type: op[0],
        args: compiled_args,
        contents: []
    }
}

export function gen_compiled(ast: SimpleArrayAst): CompiledFlowGraph {
    const result = convert_ast(ast);
    return _link_graph(result);
}

function canonicalize_arg(arg: CompiledBlockArg): CompiledBlockArg {
    if (arg.type === 'constant') {
        return arg;
    }
    else if (arg.type === 'variable' || arg.type === 'list') {
        return arg;
    }
    else {
        return {
            type: arg.type,
            value: arg.value.map(b => canonicalize_op(b)),
        }
    }
}

function canonicalize_content(content: (CompiledBlock | ContentBlock)): (CompiledBlock | ContentBlock) {
    if ((content as CompiledBlock).type) {
        return canonicalize_op((content as CompiledBlock));
    }
    else {
        return {contents: content.contents.map(c => canonicalize_content(c))};
    }
}

function canonicalize_op(op: CompiledBlock): CompiledBlock {
    delete op.id;

    switch (op.type) {
            // These operations should not appear on a properly compiled AST
        case "trigger_when_all_completed":
        case "trigger_when_first_completed":
        case "trigger_on_signal":
        case "trigger_when_all_true":
            throw new Error(`Invalid AST Operation: Operation (type:${op.type}) should now be present on a properly compiled AST.`);


            // Nothing to canonicalize
        case "wait_for_monitor":
        case "flow_last_value":
        case "jump_to_position":
        case "jump_to_block":
        case "trigger_when_first_completed":
            break;

            // Cannonicalize args and contents, but don't sort
        case "control_wait":
        case "control_wait_for_next_value":
        case "control_if_else":
        case "operator_modulo":
        case "operator_add":
        case "logging_add_log":
        case "operator_lt":
        case "operator_gt":
        case "data_setvariableto":
        case "data_variable":
        case "on_data_variable_update":
        case "data_lengthoflist":
        case "flow_get_thread_id":
        case "data_deleteoflist":
        case "data_addtolist":
        case "op_preload_getter":
        case "op_on_block_run":
            if (op.args) {
                op.args = (op.args as CompiledBlockArgList).map(arg => canonicalize_arg(arg));
            }
            if (op.contents) {
                op.contents = op.contents.map(content => canonicalize_content(content));
            }
            break;

            // Special argument handling
        case "command_call_service":
            const values = (op.args as CompiledBlockArgCallServiceDict).service_call_values;
            if (values) {
                (op.args as CompiledBlockArgCallServiceDict).service_call_values = values.map(arg => canonicalize_arg(arg));
            }
            break;

            // Canonicalize args and allow sorting them
        case "operator_and":
        case "operator_equals":
            const args = (op.args as CompiledBlockArgList).map(arg => canonicalize_arg(arg));

            // This is very inefficient, but as canonicalization only makes
            // sense on unit tests it might be acceptable
            op.args = args.sort((a, b) => stable_stringify(a).localeCompare(stable_stringify(b)));
            break;

            // Canonicalize contents and allow sorting them
        case "op_fork_execution":
            op.contents = op.contents.map(content => canonicalize_content(content));
            op.contents = op.contents.sort((a, b) => stable_stringify(a).localeCompare(stable_stringify(b)));

            // Remove redundant parameters
            if (op.args && Array.isArray(op.args)) {
                op.args = op.args.filter(a => !(a.type === 'constant' && a.value === 'exit-when-all-completed'))
            }

            break;

        default:
            if (op.type.startsWith('services.')) {
                if (op.args && Array.isArray(op.args)) {
                    op.args = (op.args as CompiledBlockArgList).map(arg => canonicalize_arg(arg));
                }
                if (op.contents) {
                    op.contents = op.contents.map(content => canonicalize_content(content));
                }
            }
            else {
                console.warn(`Unknown operation: ${op.type}`);
            }
    }

    delete op.report_state;

    return op;
}

function canonicalize_ast(ast: CompiledFlowGraph): CompiledFlowGraph {
    return ast.map(op => canonicalize_op(op));
}

export function canonicalize_ast_list(asts: CompiledFlowGraph[]): CompiledFlowGraph[] {
    // This sorting is very inefficient, but as canonicalization only makes
    // sense on unit tests it might be acceptable
    return asts.map(ast => canonicalize_ast(ast)).sort((a, b) => stable_stringify(a).localeCompare(stable_stringify(b)));
}
