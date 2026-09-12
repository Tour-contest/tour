import path from 'node:path'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv } from 'vite'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // 세 번째 인자 '' : VITE_ 접두사 없는 변수(DEV_SERVER_URL)도 로드 — 이 파일은 Node 에서만 실행되므로 번들에는 노출되지 않음
  const env = loadEnv(mode, process.cwd(), '')

  return {
    plugins: [react(), tailwindcss()],
    resolve: {
      alias: {
        '@': path.resolve(import.meta.dirname, './src'),
      },
    },
    server: {
      host: true,
      port: 3000,
      proxy: {
        '/api': { target: env.DEV_SERVER_URL, changeOrigin: true },
      },
    },
  }
})
