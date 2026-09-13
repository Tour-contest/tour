# 널널 — Web (Frontend)

관광지 혼잡도 기반 AI 챗봇 서비스의 웹 프론트엔드.

## Tech Stack

- React 19 · TypeScript · Vite
- Tailwind CSS 4
- react-router, axios, zustand

## Getting Started

```bash
pnpm install

# 프로젝트 루트에 .env.development 생성 후 아래 Environment Variables 참고해 값 채우기

pnpm dev      # http://localhost:3000
pnpm build    # 프로덕션 빌드 (tsc + vite build)
pnpm lint     # ESLint
```

## Environment Variables

`.env.development` / `.env.production` 등 [Vite 모드별 env 파일](https://vite.dev/guide/env-and-mode)에 아래 값을 채운다. `.env*`는 `.gitignore` 대상이라 저장소에는 커밋되지 않으므로, 새 환경에서는 아래 표대로 직접 만들어야 한다.

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `VITE_API_BASE_URL` | axios `baseURL`. dev에서는 **빈 값**으로 두고 Vite 프록시(`/api` → `DEV_SERVER_URL`)를 통해 same-origin으로 호출한다 (CORS 회피). 운영 빌드에서 프록시 없이 직접 호출한다면 실제 API origin을 채운다 | (dev) 비워둠 |
| `DEV_SERVER_URL` | 개발 서버(`vite.config.ts`)가 `/api` 요청을 프록시할 실제 백엔드 주소. `VITE_` 접두사가 없어 클라이언트 번들에는 노출되지 않는다 (Node 설정 파일 전용) | `https://nullnull.kr` |
| `VITE_KAKAO_REDIRECT_URI` | 카카오 OAuth 인가/콜백에 쓰는 redirect_uri. **카카오 디벨로퍼스 콘솔에 등록된 값과 정확히 일치**해야 한다(프로토콜·호스트·포트·트레일링 슬래시까지) | `http://localhost:3000/` |

`VITE_` 접두사가 붙은 값은 클라이언트 번들에 그대로 노출되므로 공개 가능한 값만 넣는다. 접두사 없는 변수(`DEV_SERVER_URL`)는 `vite.config.ts`에서 `loadEnv`로만 읽고 번들에는 포함되지 않는다.
