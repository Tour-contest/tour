import path from 'node:path'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import svgr from 'vite-plugin-svgr'
import { defineConfig, loadEnv } from 'vite'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // 세 번째 인자 '' : VITE_ 접두사 없는 변수(DEV_SERVER_URL)도 로드 — 이 파일은 Node 에서만 실행되므로 번들에는 노출되지 않음
  const env = loadEnv(mode, process.cwd(), '')

  return {
    plugins: [
      react(),
      tailwindcss(),
      // SVG 를 React 컴포넌트로: `import Icon from '@/assets/icons/x.svg?react'` → `<Icon className="size-5 text-[#…]" />`
      // 1) assets/icons/** — 단색 아이콘. 파일 안의 고정 색을 currentColor 로 바꿔 className(text-*)으로 색을 준다
      svgr({
        include: '**/assets/icons/**/*.svg?react',
        svgrOptions: {
          // svgo 는 플러그인 목록에 직접 넣어야 돈다 (svgo: true 만으로는 실행되지 않음)
          plugins: ['@svgr/plugin-svgo', '@svgr/plugin-jsx'],
          // width/height 를 1em 으로 → text-* 나 size-* 로 크기를 잡는다
          icon: true,
          svgo: true,
          svgoConfig: {
            plugins: [
              {
                name: 'preset-default',
                params: {
                  overrides: {
                    // viewBox 가 있어야 크기를 바꿔도 비율이 유지된다
                    removeViewBox: false,
                    // fill/stroke 의 고정 색 → currentColor. 'none' 은 그대로라 선 아이콘도 깨지지 않는다
                    convertColors: { currentColor: true },
                  },
                },
              },
            ],
          },
        },
      }),
      // 2) 그 밖의 svg (assets/logo/** 등) — 그라디언트·여러 색을 그대로 둔다. 크기만 className 으로
      svgr({
        exclude: '**/assets/icons/**',
        svgrOptions: {
          plugins: ['@svgr/plugin-svgo', '@svgr/plugin-jsx'],
          icon: true,
          svgo: true,
          svgoConfig: {
            plugins: [
              { name: 'preset-default', params: { overrides: { removeViewBox: false } } },
              // 그라디언트·마스크 id 를 파일명으로 접두해 같은 페이지에 svg 가 여럿 있어도 id 가 겹치지 않게 한다
              { name: 'prefixIds' },
            ],
          },
        },
      }),
    ],
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
