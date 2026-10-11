from __future__ import annotations

TITLE = "널널 — 관광지 혼잡도 안내 API"
VERSION = "1.0.0"

DESCRIPTION = """\
관광지 혼잡도를 조회하고 한적한 곳을 추천하는 서비스의 API.

조회 응답에는 data.status 가 따로 있다. success 는 요청 처리 여부, status 는 데이터
유무다. 자료가 없는 지역은 success true, status no_data 로 내려간다.

인증은 로그인 응답의 access_token 을 Authorization: Bearer 로 보낸다. 액세스 30분,
리프레시 14일이며 리프레시는 사용할 때마다 교체된다.

호출 제한은 로그인 60회/분, 비로그인 30회/분, 대화 전송 10회/분이다.
"""

TAGS = [
    {"name": "system", "description": "헬스 체크, 준비 상태, 출처 표기. 인증 불필요."},
    {"name": "auth", "description": "로그인, 토큰 갱신, 탈퇴, 카카오 계정 상태 웹훅."},
    {"name": "areas", "description": "시군구 단위 지역 조회. 지역명 해석, 혼잡 현황, 방문자 추이."},
    {"name": "attractions", "description": "관광지 검색·상세·혼잡도·대안·유사도·이미지."},
    {"name": "chat", "description": "대화 전송(SSE)과 세션·이력 관리."},
    {"name": "admin", "description": "관리자 전용. role 이 admin 이 아니면 403."},
]
