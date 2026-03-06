import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
// VITE_BASE_URL is provided by the GitHub Pages workflow (defaults to '/<repo-name>/')
// For Capacitor (Android) it stays './' so assets load over file://
  base: process.env.VITE_BASE_URL ?? './',
})
