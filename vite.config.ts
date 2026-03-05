import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // VITE_BASE_URL is set by the GitHub Pages workflow to '/alma.app.oficial/'
  // For Capacitor (Android) it stays './' so assets load over file://
  base: process.env.VITE_BASE_URL ?? './',
})
