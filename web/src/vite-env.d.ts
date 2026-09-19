/// <reference types="vite/client" />

// 번들에 들어가는 환경 변수의 타입. 키를 잘못 적으면 컴파일에서 잡힌다 (값 자체는 vite.config.ts 가 빌드 때 검사)
interface ImportMetaEnv {
    // 비우면 화면과 같은 origin
    readonly VITE_API_BASE_URL: string;
    // 카카오 콘솔에 등록된 Redirect URI 와 같아야 한다
    readonly VITE_KAKAO_REDIRECT_URI: string;
}

interface ImportMeta {
    readonly env: ImportMetaEnv;
}
