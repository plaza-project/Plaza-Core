import { FlowGraph } from '../../../flow-editor/flow_graph';
import { compile } from '../../../flow-editor/graph_analysis';
import { validate } from '../../../flow-editor/graph_validation';
import { TIME_MONITOR_ID } from '../../../flow-editor/platform_facilities';
import { gen_compiled } from '../scaffolding/graph-analysis-tools';
import { dsl_to_ast } from '../scaffolding/graph-analysis-tools-ast-dsl';
import { GraphBuilder } from '../scaffolding/graph-analysis-tools-graph-builder';
import { are_equivalent_ast } from './utils.spec';

export function gen_flow(): FlowGraph {
    const builder = new GraphBuilder();

    // Stream section
    const source = builder.add_stream('flow_utc_time', {id: 'source', message: 'UTC time'});

    const mod = builder.add_stream('operator_modulo', {args: [[source, 0], 2]});
    const cond = builder.add_stream('operator_equals', {args: [[mod, 0], 0]});

    // Stepped section
    const trigger = builder.add_trigger('trigger_when_all_true', {args: [[cond, 0]]});

    const update = builder.add_op('data_setvariableto', {
        args: [
            [f => f.add_getter('operator_add', { args: [ 1, { from_variable: 'count' } ] }) , 0] ],
        slots: { 'variable': 'count' }
    });
    const op = builder.add_op('logging_add_log', { args: [ [source, 0] ]
                                              });

    const take_cond = builder.add_if(update, null, {
        cond: [f => f.add_getter('operator_lt', { args: [ { from_variable: 'count' }, 'N' ] }), 0]
    });
    trigger.then_id(take_cond);
    update.then(op);

    const graph = builder.build();
    return graph;
}

describe('Flow-91-1: [Reactive] Take N first values.', () => {
    it('Validation should pass', async () => {
        expect(validate(gen_flow()))
            .toBeTruthy()
    });


    it('Should be able to compile', async () => {
        const compiled_flow = compile(gen_flow());

        const dsl_ast = dsl_to_ast(
            `;PM-DSL ;; Entrypoint for mmm-mode
            (wait-for-monitor from_service: "${TIME_MONITOR_ID}")
            (if (and (= (mod (flow-last-value "source" 0) 2)
                        0)
                     )
                ((if (< (get-var counter) N)
                     ((set-var counter (+ 1 (get-var counter)))
                      (log (flow-last-value "source" 0))))))
            `
        );

        const from_ast = [gen_compiled(dsl_ast)];

        are_equivalent_ast(compiled_flow, from_ast);
    });
});
