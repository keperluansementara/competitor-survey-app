import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: [],
      manifest: {
        name: 'Market Intel — Survei Outlet',
        short_name: 'Market Intel',
        description: 'Survei produk dan intelijen pasar di outlet.',
        theme_color: '#14764a',
        background_color: '#f4f7f4',
        display: 'standalone',
        start_url: '/',
        icons: [],
      },
    }),
  ],
});
