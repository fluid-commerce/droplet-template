/*
 * This file controls what inputs show up when you edit the component in the
 * Embeddable.com builder, and how it reacts to change events.
 *
 * You can delete this folder once you move to Vanilla Components post-Onboarding
 */
import {
  EmbeddedComponentMeta,
  defineComponent,
  Inputs,
} from '@embeddable.com/react';
import { Value } from '@embeddable.com/core';

import Component from './index';

export const meta = {
  name: 'ExampleTextInput',
  label: 'Example Text Input',
  category: 'Examples',
  defaultWidth: 320,
  defaultHeight: 80,
  inputs: [
    {
      name: 'label',
      type: 'string',
      label: 'Label',
      description: 'The text to show next to the textbox',
    },
  ],
  events: [
    {
      name: 'onChange',
      label: 'Change',
      properties: [
        {
          name: 'value',
          type: 'string',
        },
      ],
    },
  ],
} as const satisfies EmbeddedComponentMeta;

export default defineComponent(Component, meta, {
  props: (inputs: Inputs<typeof meta>) => {
    return {
      ...inputs,
    };
  },
  events: {
    onChange: (value) => ({ value: value || Value.noFilter() }),
  },
});
