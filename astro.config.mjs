// @ts-check
import { defineConfig } from 'astro/config';

import mdx from "@astrojs/mdx";
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  vite: {
    plugins: [tailwindcss()],
    resolve: {
      alias: {
        '@components': '/src/components',
        '@assets': '/src/assets',
      },
    },
  },
  integrations: [mdx()],
});
