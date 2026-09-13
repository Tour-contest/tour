# backend

널널 API 서버. 관광지 혼잡도 조회, 대안 추천, 대화형 안내 제공.

## 기술 스택

| 구분 | 사용 |
| --- | --- |
| 언어 | Python 3.11 이상 (서버 3.13) |
| 프레임워크 | FastAPI, uvicorn |
| DB | PostgreSQL 16, pgvector |
| ORM | SQLAlchemy 2.0 async, asyncpg |
| 외부 연동 | 공공데이터포털(TourAPI, 데이터랩, 집중률), 네이버 데이터랩, 카카오 로그인 |
| LLM | OpenAI 호환 API (Groq gpt-oss-20b, GPT-5.4 mini) |
| 임베딩 | OpenAI 호환 API (Upstage solar-embedding, gpt text-embedding-3-small)  |
| 인증 | JWT, bcrypt |

## 구조

```
app/
  api/v1/      라우터
  agent/       대화 처리 (도구 호출, 응답 생성)
  services/    외부 API 호출, 도메인 로직
  repository/  DB 모델, 쿼리
  schemas/     요청·응답 스키마
  core/        설정, 인증, 공통 응답 형식, 요청 빈도 제한
  jobs/        배치
  evals/       응답 품질 점검
```

## 준비

### 1. conda 환경

Anaconda 또는 Miniconda 설치 후 진행.

```bash
conda create -n tour python=3.13 -y
conda activate tour
pip install -r requirements.txt
```

### 2. PostgreSQL

PostgreSQL 16과 pgvector 확장 필요. 확장 생성은 슈퍼유저 권한이 있어야 해서 미리 만들어 두어야 합니다.

```bash
sudo -u postgres psql -c "CREATE ROLE tour LOGIN PASSWORD '비밀번호'"
sudo -u postgres psql -c "CREATE DATABASE tour OWNER tour"
sudo -u postgres psql -d tour -c "CREATE EXTENSION IF NOT EXISTS vector"
```

테이블은 서버 기동 시 자동 생성. 마이그레이션 도구가 없어 기존 테이블에 컬럼을 추가하면 `ALTER TABLE` 직접 실행이 필요합니다.

### 3. .env

**공공데이터 · 외부 API**

| 항목 | 의미 |
| --- | --- |
| DATA_GO_KR_SERVICE_KEY | 공공데이터포털 인증키. Decoding 키를 설정합니다. Encoding 키를 설정하면 이중 인코딩되어 인증에 실패합니다 |
| TOURAPI_MOBILE_APP | TourAPI 요청에 포함하는 앱 이름입니다. 값에 제약은 없으며 식별 용도입니다 |
| NAVER_SEARCH_CLIENT_ID | 네이버 데이터랩 검색어 트렌드 키. 검색 관심도에만 사용합니다 |
| NAVER_SEARCH_CLIENT_SECRET | 위와 한 쌍입니다. 설정하지 않으면 관심도가 no_data 로 응답합니다 |

**LLM (대화)**

| 항목 | 의미 |
| --- | --- |
| LLM_PROVIDER | 모델 제공자 표기. 현재 groq 입니다. 코드에서는 참조하지 않으며 제공자 전환은 LLM_BASE_URL 로 합니다 |
| LLM_BASE_URL | OpenAI 호환 엔드포인트. 제공자를 바꾸면 이 값만 교체합니다 |
| LLM_API_KEY | 모델 키. 설정하지 않으면 대화가 규칙 기반으로 동작합니다. 응답 형태는 동일합니다 |
| LLM_MODEL | 도구 선택과 문장 작성에 쓰는 모델 |
| LLM_MODEL_LIGHT | 질문 정리 같은 가벼운 작업용 모델 |
| LLM_TEMPERATURE_TOOL | 도구 선택 온도. 0 이어야 같은 질문에 같은 도구를 고릅니다 |
| LLM_TEMPERATURE_COMPOSE | 문장 작성 온도 |
| LLM_TIMEOUT | 모델 응답 대기 시간(초) |
| LLM_REASONING_EFFORT | gpt-oss 추론 강도입니다. low 로 유지합니다 |
| LLM_MAX_TOKENS_TOOL | 도구 선택 응답 상한 |
| LLM_MAX_TOKENS_COMPOSE | 문장 작성 응답 상한 |
| LLM_PRICE_IN_1M | 입력 100만 토큰당 단가(달러). 관리자 화면의 비용 표시에만 사용합니다 |
| LLM_PRICE_OUT_1M | 출력 100만 토큰당 단가(달러) |
| OPTIMIZER_TIMEOUT | 질문 정리 단계 제한 시간(초). 넘기면 원문 그대로 진행합니다 |
| OVERVIEW_MAX_CHARS | 모델에 넘기는 소개문 길이 상한 |
| MAX_TOOL_ROUNDS | 한 질문에 허용하는 도구 호출 라운드 수 |

**임베딩 (유사 관광지)**

| 항목 | 의미 |
| --- | --- |
| EMBEDDING_PROVIDER | 임베딩 제공자. 현재는 upstage api 를 사용합니다 |
| EMBEDDING_BASE_URL | OpenAI 호환 엔드포인트 |
| EMBEDDING_MODEL | 임베딩 모델명 |
| EMBEDDING_API_KEY | 임베딩 키. 설정하지 않으면 유사 관광지가 no_data 로 응답합니다 |
| EMBEDDING_DIM | 벡터 차원. 바꾸면 기동할 때 attraction_vectors 를 재생성하므로 기존 벡터가 전부 삭제됩니다 |
| SIMILARITY_MIN | 코사인 하한. 이 값 미만은 버립니다. 절대값 분포가 모델마다 달라 제공자를 바꾸면 같이 조정해야 합니다 |

**인증**

| 항목 | 의미 |
| --- | --- |
| JWT_SECRET | 토큰 서명 키. 32자 미만이면 서버가 기동하지 않습니다. 노출되면 토큰 위조가 가능합니다 |
| JWT_ACCESS_TTL | 액세스 토큰 유효 시간(초). 1800 은 30분입니다 |
| JWT_REFRESH_TTL | 리프레시 토큰 유효 시간(초). 1209600 은 14일입니다 |
| ADMIN_LOGIN_ID | 관리자 로그인 아이디. 이 값으로 계정을 자동 생성합니다 |
| ADMIN_PASSWORD | 관리자 비밀번호. 운영 구성에서 비어 있거나 기본값이면 기동하지 않습니다 |
| ALLOW_DEV_LOGIN | 개발용 로그인 활성 여부. 운영은 false 입니다. false 이면 서버가 운영 구성으로 판단하고 비밀값을 검사합니다 |
| ALLOW_ANONYMOUS_CHAT | 비로그인 대화 허용 여부. 현재 코드에서는 참조하지 않습니다 |

**소셜 로그인**

| 항목 | 의미 |
| --- | --- |
| KAKAO_CLIENT_ID | 카카오 REST API 키. 공개 식별자이므로 클라이언트에 전달됩니다 |
| KAKAO_CLIENT_SECRET | 설정하지 않은 앱에 값을 전송하면 거절됩니다 |
| KAKAO_APP_ID | 숫자 앱 ID. 네이티브 SDK 경로에서 우리 앱이 발급한 토큰인지 검증하는 데 사용합니다 |
| KAKAO_ADMIN_KEY | 어드민 키. 탈퇴 시 연결 해제 호출에 사용합니다. 설정하지 않으면 서버 DB 만 삭제되고 카카오 연결이 잔존합니다 |

**데이터베이스**

| 항목 | 의미 |
| --- | --- |
| DATABASE_URL | PostgreSQL 접속 주소. 비밀번호에 @ : / # ? % 가 포함되면 URL 인코딩해야 합니다 |

**공공데이터 조회 정책**

| 항목 | 의미 |
| --- | --- |
| DAILY_UPSTREAM_QUOTA | 서버의 API 일일 상한. 초과하면 503 UPSTREAM_QUOTA_EXCEEDED 로 응답합니다 |
| MAX_UPSTREAM_CALLS_PER_REQUEST | 요청 1건이 사용할 수 있는 호출 상한 |
| UPSTREAM_CACHE_ENABLED | 한 요청 안의 중복 호출 제거 여부. 원천 데이터를 저장하는 캐시가 아닙니다 |
| UPSTREAM_CACHE_TTL_DETAIL | 상세 조회 중복 제거 유지 시간(초) |
| UPSTREAM_CACHE_TTL_CROWD | 집중률 조회 중복 제거 유지 시간(초) |
| TARRLTETAR_BASE_YM | 연관 관광지 조회 기준 연월 |
| CROWD_MAX_DAYS | 집중률 조회 최대 일수 |
| CROWD_PAGE_SIZE | 집중률을 1회에 수신하는 건수 |
| VISITOR_LAG_DAYS | 방문자 추이 지연 일수. 약 75일 지연되므로 data_through 를 함께 표시합니다 |
| TREND_WEEKS | 검색 관심도 기본 집계 주 수 |
| REPORT_TZ | 일일 집계 기준 시간대. 포털 할당량이 한국 자정에 초기화됩니다 |

**화면 표기 기준**

| 항목 | 의미 |
| --- | --- |
| CROWD_THRESHOLD_HIGH | 이 값 이상이면 혼잡으로 분류합니다 |
| CROWD_THRESHOLD_LOW | 이 값 미만이면 한적으로 분류합니다. 사이 구간은 보통입니다 |
| RECENT_ATTRACTIONS_LIMIT | 최근 본 관광지 보관 개수 |
| MAX_SESSIONS_PER_USER | 회원당 대화 세션 보관 개수. 초과하면 오래된 것부터 삭제합니다 |
| CONTEXT_RAW_TURNS | 모델에 원문 그대로 전달하는 최근 대화 턴 수입니다. 그보다 오래된 것은 요약하여 전달합니다 |

**요청 제한과 보안**

| 항목 | 의미 |
| --- | --- |
| RATE_ANON_PER_MIN | 비로그인 분당 요청 수 |
| RATE_USER_PER_MIN | 로그인 분당 요청 수 |
| RATE_CHAT_PER_MIN | 대화 분당 요청 수. 일반 상한과 별도로 집계합니다 |
| CORS_ORIGINS | 허용 오리진 목록. 운영 구성에서 별표 하나만 지정하면 기동하지 않습니다 |
| TRUST_FORWARDED_FOR | X-Forwarded-For 를 신뢰할지 여부. nginx 뒤에 있으면 true 로 설정합니다. 직결 구성에서 true 로 두면 헤더 위조로 레이트리밋이 무력화됩니다 |

운영 구성(ALLOW_DEV_LOGIN=false)에서는 JWT_SECRET 테스트용 값, 관리자 비밀번호 기본값, CORS_ORIGINS `*` 사용 시 기동 실패.

## 실행

```bash
cd backend
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

운영환경에서는 `--reload` 제거.

확인

```bash
curl -s localhost:8000/api/v1/readyz
```

| 필드 | 정상 | 아닐 때 |
| --- | --- | --- |
| areas_loaded | 275 | 0이면 지역 코드 적재 실패 |
| service_key_set | true | 공공데이터 키 없음 |
| llm_enabled | true | 규칙 기반 응답 |
| embedding_ready | true | 유사 관광지 빈 응답 |

API 문서는 `http://127.0.0.1:8000/docs` 참고

## 배치

서버와 별도로 필요할 때 실행하며, 공공데이터 할당량을 쓰므로 `--budget` 으로 상한을 지정할 수 있습니다.

```bash
python -m app.jobs.run status                          # 적재 현황
python -m app.jobs.run area-codes                      # 지역 코드표 재적재
python -m app.jobs.run crowd-flags                     # 지역별 혼잡도 제공 여부 확인
python -m app.jobs.run name-map --all --budget 800     # 혼잡도 관광지명과 관광정보 매핑
python -m app.jobs.run vectors --all --budget 400      # 유사 관광지 벡터 생성
```

`--all` 대신 시군구 코드를 주면 해당 지역만 처리하며, 할당량 도달 시 체크포인트 저장 후 중단, 다음 실행에서 이어서 진행 됩니다.

## 서버 환경

### 서버 기본경로

/root/tour/tour-crowding-test

### 구성

| 항목 | 값 |
| --- | --- |
| OS | Rocky Linux 8.8 |
| 도메인 | nullnull.kr, www.nullnull.kr (Let's Encrypt SSL 적용) |
| 저장소 | /root/tour/tour-crowding-test |
| 백엔드 | backend/, uvicorn, 127.0.0.1:8000 |
| DB | PostgreSQL 16 (PGDG 저장소), pgvector 확장 |
| 서비스 | nullnull.service (systemd) |
| nginx 설정 | /etc/nginx/nginx.conf |

### 파이썬 환경 (Anaconda)

시스템 파이썬을 쓰지 않고 conda 환경을 사용합니다.

| 항목 | 값 |
| --- | --- |
| 설치 위치 | /root/anaconda3 |
| 환경 이름 | tour |
| 실행 파일 | /root/anaconda3/envs/tour/bin/python |

```bash
# 환경 진입
conda activate tour

# 의존성 설치·갱신
/root/anaconda3/envs/tour/bin/pip install -r /root/tour/tour-crowding-test/backend/requirements.txt
```

### 기본 명령어

**백엔드**

```bash
systemctl status nullnull          # 상태
systemctl restart nullnull         # 재시작
systemctl stop nullnull            # 중지
journalctl -u nullnull -f          # 실시간 로그
journalctl -u nullnull -n 50 --no-pager   # 최근 50줄 로그
```

기동 확인은 readyz api로 확인 합니다.

```bash
curl -s localhost:8000/api/v1/readyz
```

| 필드 | 정상값 | 아닐 때 |
| --- | --- | --- |
| areas_loaded | 275 | 0 이면 지역 데이터가 없습니다 |
| llm_enabled | true | false 면 대화가 규칙 기반으로 동작합니다 |
| embedding_ready | true | false 면 유사 관광지가 빈 값으로 응답합니다 |
| service_key_set | true | false 면 관광 데이터 조회가 전부 실패합니다 |

**nginx**

```bash
nginx -t                    # 설정 문법 검사
systemctl reload nginx      # 무중단 반영
tail -f /var/log/nginx/error.log # 로그
```

**PostgreSQL**

```bash
systemctl status postgresql-16
psql -h 127.0.0.1 -U tour -d tour # 접속
```
