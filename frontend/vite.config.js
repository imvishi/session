import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // The API only allows this origin (CORS), so fail rather than quietly move to another port.
    strictPort: true,
  },
  test: {
    environment: 'jsdom',
    setupFiles: './src/test-setup.js',
  },
})
