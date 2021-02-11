import { FlowGraph } from '../../../flow-editor/flow_graph';
import { get_unreachable } from '../../../flow-editor/graph_analysis';
import { validate } from '../../../flow-editor/graph_validation';
import { GraphBuilder } from '../scaffolding/graph-analysis-tools-graph-builder';

// @ts-ignore
import * as _04_no_start_loop from '../samples/04_no_start_loop.js';

export function gen_flow(): FlowGraph {
    const builder = new GraphBuilder();

    // Services
    const weather = builder.add_service('536bf266-fabf-44a6-ba89-a0c71b8db608');
    const chat = builder.add_service('de5baefb-13da-457e-90a5-57a753da8891');

    // Values
    const loc = builder.add_enum_node(weather, 'get_locations', 'Vigo', '12/36/057/7', {id: 'loc'});
    const channel = builder.add_enum_node(chat, 'get_known_channels', 'Bot testing', '-137414823', {id: 'channel'});

    // Stepped section
    const msg1 = builder.add_op('send_message', { namespace: chat,
                                                  id: 'first',
                                                  args: [channel,
                                                         [(b) => b.add_getter('get_today_max_in_place', { id: 'first-getter',
                                                                                                          namespace: weather,
                                                                                                          args: [loc]
                                                                                                        }), 0]]
                                                });

    const msg2 = builder.add_op('send_message', { namespace: weather,
                                                  id: 'second',
                                                  args: [channel,
                                                         [(b) => b.add_getter('get_today_max_in_place', { id: 'second-getter',
                                                                                                          namespace: weather,
                                                                                                          args: [loc]
                                                                                                        }), 0]]
                                                });

    msg1.then(msg2).then(msg1);

    const graph = builder.build();
    return graph;
}

describe('Flow-04: No start loop.', () => {
    it('Validation should FAIL', async () => {
        expect(() => validate(gen_flow()))
            .toThrowError(/^ValidationError:.*Unreachable blocks?.*/i)
    });

    it('Should find an unreachable blocks', async () => {
        expect(get_unreachable(gen_flow()).sort()).toEqual([
            "first",
            "second",
            "first-getter",
            "second-getter",
            "loc",
            "channel"
        ].sort());
    });

    describe('Sample-based tests.', async () => {
        it('Should find unreachable blocks', async () => {
            expect(get_unreachable(_04_no_start_loop as FlowGraph).sort()).toEqual([
                "4652b79c-603b-4add-9164-92508be43fdf",
                "1545b4f2-8b4f-4c59-ae0b-a0a0e5d6746c",
                "f1b8670c-0001-4417-8a39-2c52f5140383",
                "099ee247-851d-41bb-819c-5347247cd06a",
            ].sort());
        });
    });
});
