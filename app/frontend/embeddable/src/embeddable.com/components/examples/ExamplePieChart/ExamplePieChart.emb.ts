/*
 * This file controls what inputs show up when you edit the component in the
 * Embeddable.com builder, and how it loads data.
 *
 * You can delete this folder once you move to Vanilla Components post-Onboarding
 */
import {
  EmbeddedComponentMeta,
  Inputs,
  defineComponent,
} from '@embeddable.com/react';
import { Dataset, Dimension, Measure, loadData } from '@embeddable.com/core';

import Component from './index';

export const meta = {
  name: 'ExamplePieChart',
  label: 'Example Pie Chart',
  classNames: ['inside-card'],
  category: 'Examples',
  inputs: [
    {
      name: 'ds',
      type: 'dataset',
      label: 'Dataset to display',
      category: 'Configure chart',
    },
    {
      name: 'slice',
      type: 'dimension',
      label: 'Slice',
      config: {
        dataset: 'ds',
      },
      category: 'Configure chart',
    },
    {
      name: 'metric',
      type: 'measure',
      label: 'Metric',
      config: {
        dataset: 'ds',
      },
      category: 'Configure chart',
    },
    {
      name: 'showLegend',
      type: 'boolean',
      label: 'Turn on the legend',
      category: 'Chart settings',
      defaultValue: true,
    },
  ],
} as const satisfies EmbeddedComponentMeta;

export default defineComponent(Component, meta, {
  props: (inputs: Inputs<typeof meta>) => {
    return {
      ...inputs,
      results: loadData({
        from: inputs.ds,
        select: [inputs.slice, inputs.metric]
      }),
    };
  },
});
