import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'node:path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { '@': path.resolve(__dirname, 'src') },
  },
  server: {
    port: 5174,
    proxy: {
      // Future BFF / console API
      '/api': {
        target: process.env.VITE_API_PROXY || 'https://console.archgate.com.br',
        changeOrigin: true,
        secure: false,
      },
    },
  },
})
