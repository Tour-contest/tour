# 널널 — Web (Frontend)

관광지 혼잡도 기반 AI 챗봇 서비스의 웹 프론트엔드.

## Tech Stack

- React 19 · TypeScript · Vite
- Tailwind CSS 4
- react-router, axios, zustand

## Getting Started

```bash
pnpm install

# .env.example 을 복사해 .env.development 를 만들고 값을 채운다 (아래 Environment Variables 참고)

pnpm dev      # http://localhost:3000 (LAN 에도 열림)
pnpm build    # 프로덕션 빌드 (tsc + vite build) → dist/
pnpm preview  # dist/ 를 3000 포트로 서빙 (프로덕션 빌드 시연용)
pnpm lint     # ESLint
```

## Environment Variables

`.env.development`(dev) / `.env.production`(build · preview) 등 [Vite 모드별 env 파일](https://vite.dev/guide/env-and-mode)에 아래 값을 채운다. 실제 값이 든 `.env*` 는 `.gitignore` 대상이라 저장소에 올라가지 않는다. 견본인 `.env.example` 만 커밋되므로 새 환경에서는 그 파일을 복사해서 만든다.

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `VITE_API_BASE_URL` | axios `baseURL`. **비워 두면** 화면과 같은 origin 의 `/api/v1/...` 로 부른다. dev · preview 는 Vite 프록시(`/api` → `DEV_SERVER_URL`)가 이를 실제 서버로 넘긴다. 서버가 CORS 헤더를 주지 않으므로 다른 origin 을 적어도 브라우저에서 막힌다 | 비워둠 |
| `DEV_SERVER_URL` | dev · preview 프록시가 `/api` 요청을 넘길 실제 백엔드 주소. `VITE_` 접두사가 없어 번들에는 들어가지 않는다 (`vite.config.ts` 전용) | `https://nullnull.kr` |
| `VITE_KAKAO_REDIRECT_URI` | 카카오 OAuth 인가/콜백의 `redirect_uri`. **카카오 디벨로퍼스 콘솔에 등록된 값과 글자 단위로 같아야 한다** (프로토콜 · 호스트 · 포트 · 경로) | `http://192.168.137.1:3000/oauth/kakao/callback` |

`VITE_` 접두사가 붙은 값은 번들에 그대로 들어가므로 공개 가능한 값만 넣는다. 두 변수의 타입은 `src/vite-env.d.ts` 에 선언돼 있어 키 오타는 컴파일에서 잡힌다.

`vite.config.ts` 는 빌드·실행 전에 `VITE_KAKAO_REDIRECT_URI` 와 `DEV_SERVER_URL` 이 있는지 검사하고, 없으면 어떤 파일에 무엇을 적어야 하는지 알려 주며 멈춘다. 값이 빠진 채 빌드되면 카카오 로그인 주소가 `undefined` 로 나가는 식으로 실행 중에야 드러나기 때문이다.

## 프로덕션 빌드 · 데모

### 로컬(노트북)에서 프로덕션 빌드 시연

```bash
pnpm build      # .env.production 을 읽어 dist/ 생성
pnpm preview    # http://<이 PC 주소>:3000
```

- `preview` 도 dev 와 같은 3000 포트에 같은 `/api` 프록시를 붙여 둔 상태다. 카카오 콘솔에 등록한 `…:3000/oauth/kakao/callback` Redirect URI 를 그대로 쓰기 위해서다.
- `.env.production` 에는 개발과 같은 Redirect URI(핫스팟 IP) 를 두고 `VITE_API_BASE_URL` 은 비운다.
- 확인 항목: `/` 와 `/c/<id>` 같은 딥링크가 앱으로 열리는지, `/api/v1/readyz` 가 서버 응답을 돌려주는지, 카카오 로그인이 되돌아오는지.

### 서버(nullnull.kr)에 올려서 시연

서버는 `/` 에서 이 앱의 정적 빌드를 서빙하고, 없는 경로는 앱 셸(`index.html`)로 돌려준다 (SPA fallback). CORS 를 열지 않으므로 화면은 반드시 API 와 같은 origin 에 있어야 한다.

1. `.env.production` 의 `VITE_KAKAO_REDIRECT_URI` 를 `https://nullnull.kr/oauth/kakao/callback` 으로 바꾼다.
2. 카카오 디벨로퍼스 콘솔에 같은 주소를 Redirect URI 로 등록한다.
3. `pnpm build` 후 `dist/` 내용을 서버의 정적 루트에 올린다.

### 점검 체크리스트

- [ ] `pnpm build` 가 env 검사를 통과하고 `dist/index.html` 의 `lang="ko"` · 제목 · 파비콘이 맞다
- [ ] 번들(`dist/assets/index-*.js`) 안에 카카오 Redirect URI 가 들어 있고, `DEV_SERVER_URL` 값은 들어 있지 않다
- [ ] preview 또는 서버에서 딥링크 → 200 (앱 셸), `/api/v1/readyz` → 서버 JSON
- [ ] 카카오 로그인 → 콜백 → 홈까지 한 바퀴

## 코드 규칙 (요약)

- 컴포넌트 props 타입은 `XxxNeedProps`, 스타일 상수는 파일 아래 `//style configuration` 아래에 `clsx(...)` 로 둔다.
- 하위 파일이 있는 컴포넌트만 폴더로 묶고(`index.tsx` + 이름을 가진 옆 파일), UI 가 아닌 계산·상수는 `utils/`, 페이지에 묶인 훅은 그 페이지의 `hooks/` 에 둔다. 여러 화면이 쓰는 훅은 `src/hooks/`.
- 얇은 호버 스크롤바는 `index.css` 의 `scrollbar-thin-hover` 유틸리티를 쓴다.
