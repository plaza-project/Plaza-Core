import { ToolboxDescription } from '../base_toolbox_description';
import { UI_ICON } from '../definitions';
import { ResponsivePageBuilder, ResponsivePageGenerateTree } from './renderers/responsive_page';
import { SimpleButtonBuilder } from './renderers/simple_button';
import { HorizontalUiSectionBuilder, HorizontalUiSectionGenerateTree } from './renderers/horizontal_ui_section';
import { FixedTextBuilder } from './renderers/fixed_text';
import { DynamicTextBuilder } from './renderers/dynamic_text';
import { FixedImageBuilder } from './renderers/fixed_image';
import { HorizontalSeparatorBuilder } from './renderers/horizontal_separator';
import { SimpleUiCardBuilder, SimpleUiCardGenerateTree } from './renderers/simple_ui_card';
import { LinkAreaBuilder, LinkAreaGenerateTree } from './renderers/link_area';
import { TextBoxBuilder } from './renderers/text_box';

export const UiToolboxDescription: ToolboxDescription = [
    {
        id: 'basic_UI',
        name: 'Basic UI',
        blocks: [
            {
                icon: UI_ICON,
                type: 'ui_flow_block',
                id: 'simple_button',
                builder: SimpleButtonBuilder,
                outputs: [
                    {
                        type: "user-pulse",
                    },
                    {
                        name: "button text",
                        type: "string",
                    }
                ]
            },
            {
                icon: UI_ICON,
                type: 'ui_flow_block',
                id: 'text_box',
                builder: TextBoxBuilder,
                outputs: [
                    {
                        name: "On change",
                        type: "user-pulse",
                    },
                    {
                        name: "Contents",
                        type: "string",
                    }
                ]
            },
            {
                icon: UI_ICON,
                type: 'ui_flow_block',
                id: 'fixed_text',
                builder: FixedTextBuilder,
            },
            {
                icon: UI_ICON,
                type: 'ui_flow_block',
                id: 'dynamic_text',
                builder: DynamicTextBuilder,
                inputs: [
                    {
                        type: "any",
                    },
                ]
            },
            {
                icon: UI_ICON,
                type: 'ui_flow_block',
                id: 'horizontal_separator',
                builder: HorizontalSeparatorBuilder,
            },
            {
                icon: UI_ICON,
                type: 'ui_flow_block',
                id: 'fixed_image',
                builder: FixedImageBuilder,
            },
            {
                icon: UI_ICON,
                type: 'ui_flow_block',
                subtype: 'container_flow_block',
                id: 'responsive_page_holder',
                builder: ResponsivePageBuilder,
                gen_tree: ResponsivePageGenerateTree,
                isPage: true,
                is_internal: true,
            },
            {
                icon: UI_ICON,
                type: 'ui_flow_block',
                subtype: 'container_flow_block',
                id: 'horizontal_ui_section',
                builder: HorizontalUiSectionBuilder,
                gen_tree: HorizontalUiSectionGenerateTree,
            },
            {
                icon: UI_ICON,
                type: 'ui_flow_block',
                subtype: 'container_flow_block',
                id: 'simple_card',
                builder: SimpleUiCardBuilder,
                gen_tree: SimpleUiCardGenerateTree,
            },
            {
                icon: UI_ICON,
                type: 'ui_flow_block',
                subtype: 'container_flow_block',
                id: 'link_area',
                builder: LinkAreaBuilder,
                gen_tree: LinkAreaGenerateTree,
            },
        ]
    }
];
