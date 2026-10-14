import { resolve } from 'node:path';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

// The public site is a set of static pages served by the Worker's asset binding.
// Each page keeps its existing URL so the Worker routes and links stay unchanged.
const pages = ['index', 'privacy', 'withdraw', 'report', 'admin'];

export default defineConfig({
  root: 'web',
  plugins: [react(), tailwindcss()],
  build: {
    outDir: '../dist',
    emptyOutDir: true,
    // Every asset is a separate same-origin file: the Content-Security-Policy allows no inline scripts or styles.
    assetsInlineLimit: 0,
    rollupOptions: { input: Object.fromEntries(pages.map(page => [page, resolve(import.meta.dirname, 'web', `${page}.html`)])) },
  },
  server: { proxy: { '/api': 'http://127.0.0.1:8787' } },
});
