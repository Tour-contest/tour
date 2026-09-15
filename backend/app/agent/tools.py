from __future__ import annotations

from app.core.config import settings
from app.core.errors import BudgetExceeded, QuotaExceeded
from app.services import usecase

SCHEMA = [
    {
        "type": "function",
        "function": {
            "name": "resolve_area",
            "description": (
                "지역명을 시군구 코드로 바꾼다. 지역이 언급된 요청에서 가장 먼저 부른다. "
                "status 가 ambiguous 면 다른 도구를 부르지 말고 사용자에게 어느 지역인지 되물어라."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "사용자가 말한 지역 표현. 예: 경주, 경북 경주, 제주시",
                    }
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "find_attraction",
            "description": (
                "관광지명으로 관광지를 찾는다. resolve_area 로 지역을 확인했으면 "
                "signgu_cd 를 반드시 넣어라. 안 넣으면 전국의 동명 관광지가 섞여 나온다. "
                "응답의 confident 가 true 면 items[0] 이 확실한 답이니 되묻지 말고 그대로 써라. "
                "false 이고 후보가 여러 개면 그때만 사용자에게 어느 곳인지 물어라."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "name": {"type": "string", "description": "관광지명"},
                    "signgu_cd": {"type": "string", "description": "resolve_area 가 준 5자리 코드"},
                },
                "required": ["name"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_crowding",
            "description": (
                "지역의 관광지 혼잡도를 조회한다. content_ids 를 주면 그 관광지들만, "
                "안 주면 지역 전체 현황 요약이 나온다. "
                "여러 관광지가 필요하면 배열로 한 번에 넣어라. 하나씩 반복해서 부르지 마라. "
                "이 수치는 한국관광공사가 산출한 예측값이며 실시간 실측이 아니다. "
                "응답에 coverage 가 있으면 전체 몇 곳 중 몇 곳을 본 결과인지 반드시 밝혀라."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "signgu_cd": {"type": "string", "description": "시군구 코드 5자리"},
                    "content_ids": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "관광지 식별자 배열. 생략하면 지역 전체 요약",
                    },
                    "date_from": {"type": "string", "description": "YYYY-MM-DD. 생략하면 오늘"},
                    "days": {"type": "integer", "description": "조회 일수. 기본 7, 최대 28"},
                },
                "required": ["signgu_cd"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "recommend_alternatives",
            "description": (
                "기준 관광지보다 덜 붐비는 대안을 추천한다. 순위와 근거는 이미 계산돼 있으니 "
                "순서를 바꾸지 말고 reason 을 문장으로 풀어 쓰기만 해라. "
                "sort_basis 가 crowding 이 아니면 무엇을 기준으로 골랐는지, "
                "relaxed 가 true 면 조건을 완화했다는 것을 반드시 밝혀라."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "content_id": {"type": "string", "description": "기준 관광지 식별자"},
                    "date": {"type": "string", "description": "YYYY-MM-DD"},
                    "limit": {"type": "integer", "description": "기본 5"},
                },
                "required": ["content_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_places",
            "description": (
                "지역에서 갈래별로 갈 만한 곳 목록을 가져온다. 갈래는 한국관광공사 "
                "분류체계 기준이다. '태안 캠핑장', '전주 음식점', '경주 숙소' 같은 요청에 쓴다. "
                "사용자가 캠핑·야영·글램핑·카라반을 말하면 반드시 category='캠핑' 으로 불러라. "
                "'숙박' 으로 부르면 펜션·호텔까지 섞여 나온다. "
                "의료·온천·스파·한방·찜질방·힐링을 말하면 category='웰니스' 로 불러라. "
                "혼잡도(집중률)는 관광지 대상이라 이 목록에는 없다. "
                "혼잡도를 아는 것처럼 말하지 말고 이름과 위치만 안내해라. "
                "목록 순서는 인기순이 아니다. 정렬 기준을 지어내서 말하지 마라."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "signgu_cd": {"type": "string", "description": "resolve_area 가 준 5자리 코드"},
                    "category": {
                        "type": "string",
                        "description": "찾을 갈래. 캠핑장은 '캠핑' 을 쓴다",
                        "enum": [
                            "자연관광", "역사관광", "문화관광", "체험관광", "레저스포츠",
                            "축제공연행사", "쇼핑", "음식", "숙박", "캠핑", "웰니스",
                            "관광지", "여행코스",
                        ],
                    },
                    "limit": {"type": "integer", "description": "기본 10"},
                },
                "required": ["signgu_cd", "category"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_festivals",
            "description": (
                "지역에서 진행 중이거나 예정된 축제·행사 목록. "
                "'이번 주말 전주 축제 있어?' 같은 요청에 쓴다. date 를 주면 그 시점 기준이다. "
                "각 항목의 period 가 행사 기간이니 언제 하는지 같이 안내해라. "
                "사용자가 물은 날짜가 period 안에 있을 때만 '그때 한다'고 말해라. "
                "기간 밖이면 예정이라고 구분해서 안내해라."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "signgu_cd": {"type": "string", "description": "resolve_area 가 준 5자리 코드"},
                    "date": {"type": "string", "description": "YYYY-MM-DD. 생략하면 오늘"},
                    "limit": {"type": "integer", "description": "기본 10"},
                },
                "required": ["signgu_cd"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "find_pet_friendly",
            "description": (
                "지역에서 반려동물 동반 가능으로 등록된 관광지만 걸러서 가져온다. "
                "'애견 동반 갈 만한 곳', '강아지랑 갈 수 있는 데' 같은 지역 단위 질문에 쓴다. "
                "각 항목의 note 가 동반 구분(전구역/일부구역)이니 같이 안내해라. "
                "사용자가 '공원 말고 식당'처럼 종류를 좁히면 category 를 넣어 다시 불러라. "
                "특정 관광지 하나의 동반 여부는 get_attraction_detail 로 확인한다."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "signgu_cd": {"type": "string", "description": "resolve_area 가 준 5자리 코드"},
                    "category": {
                        "type": "string",
                        "enum": ["음식", "숙박", "쇼핑", "문화관광", "레저스포츠", "캠핑"],
                        "description": "생략하면 관광지·문화시설·레포츠에서 찾는다",
                    },
                    "limit": {"type": "integer", "description": "기본 8"},
                },
                "required": ["signgu_cd"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_interest_trend",
            "description": (
                "관광지들의 최근 검색 관심도 추세. 혼잡도를 조회한 뒤 보조로 부른다. "
                "비교할 관광지는 names 배열에 한 번에 넣어라. 따로 부르면 값끼리 비교가 안 된다. "
                "rising 이면 예측보다 붐빌 수 있다는 정도로만 쓰고, 이걸 혼잡도 대신 쓰지 마라."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "names": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "관광지명 배열. 최대 5개",
                    },
                    "weeks": {"type": "integer", "description": "기본 8"},
                },
                "required": ["names"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_attraction_detail",
            "description": (
                "관광지의 개요, 운영시간, 휴무일, 주차, 문의처, 반려동물 동반 정보를 가져온다. "
                "사용자가 상세나 반려동물 동반 여부를 물었을 때 불러라. "
                "응답에 없는 항목은 모른다고 답해야 한다."
            ),
            "parameters": {
                "type": "object",
                "properties": {"content_id": {"type": "string"}},
                "required": ["content_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_area_visitors",
            "description": (
                "시군구 방문자 수 추세. 통신 데이터 기반이고 두 달쯤 지연된 값이라 "
                "'요즘'이나 '최근'이라고 말하면 안 된다. 개별 관광지 혼잡도를 이걸로 대신하지 마라."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "signgu_cd": {"type": "string"},
                    "months": {"type": "integer", "description": "기본 3. 최대 3"},
                },
                "required": ["signgu_cd"],
            },
        },
    },
]

CARD_OF = {
    "find_attraction": "attraction_list",
    "list_places": "attraction_list",
    "list_festivals": "attraction_list",
    "find_pet_friendly": "attraction_list",
    "get_crowding": "crowd",
    "recommend_alternatives": "alternatives",
    "get_interest_trend": "interest",
    "get_attraction_detail": "detail",
    "get_area_visitors": "visitors",
}

STAGE_OF = {
    "resolve_area": ("resolving", "위치 확인 중"),
    "find_attraction": ("searching", "관광지 찾는 중"),
    "list_places": ("searching", "주변 시설 찾는 중"),
    "list_festivals": ("searching", "축제·행사 찾는 중"),
    "find_pet_friendly": ("searching", "반려동물 동반 가능한 곳 찾는 중"),
    "get_crowding": ("crowd", "혼잡도 확인 중"),
    "recommend_alternatives": ("alternatives", "근처 한적한 곳 찾는 중"),
    "get_interest_trend": ("crowd", "검색 관심도 보는 중"),
    "get_attraction_detail": ("searching", "상세 정보 가져오는 중"),
    "get_area_visitors": ("overview", "지역 방문자 추세 보는 중"),
}


async def run(name: str, args: dict, session_id: str | None = None) -> dict:
    try:
        if name == "resolve_area":
            return await usecase.resolve_area(str(args.get("query", "")))

        if name == "find_attraction":
            return await usecase.find_attraction(
                str(args.get("name", "")), args.get("signgu_cd") or None, session_id
            )

        if name == "get_crowding":
            ids = args.get("content_ids") or None
            if isinstance(ids, str):
                ids = [ids]
            return await usecase.get_crowding(
                str(args["signgu_cd"]),
                ids,
                args.get("date_from"),
                int(args.get("days") or 7),
                session_id,
            )

        if name == "recommend_alternatives":
            return await usecase.recommend_alternatives(
                str(args["content_id"]),
                args.get("date"),
                int(args.get("limit") or 5),
                session_id,
            )

        if name == "list_places":
            return await usecase.list_places(
                str(args["signgu_cd"]),
                str(args.get("category", "")),
                int(args.get("limit") or 10),
                session_id,
            )

        if name == "list_festivals":
            return await usecase.list_festivals(
                str(args["signgu_cd"]),
                args.get("date"),
                int(args.get("limit") or 10),
                session_id,
            )

        if name == "find_pet_friendly":
            return await usecase.find_pet_friendly(
                str(args["signgu_cd"]),
                int(args.get("limit") or 8),
                session_id,
                category=args.get("category") or None,
            )

        if name == "get_interest_trend":
            names = args.get("names") or []
            if isinstance(names, str):
                names = [names]
            return await usecase.interest_trend(names, args.get("weeks"))

        if name == "get_attraction_detail":
            return await usecase.attraction_detail(
                str(args["content_id"]), session_id, include_pet=True
            )

        if name == "get_area_visitors":
            months = int(args.get("months") or 3)
            weeks = min(months * 4, settings.visitor_weeks_max)
            return await usecase.area_visitors(str(args["signgu_cd"]), weeks=weeks)

        return {"status": "unknown_tool", "message": f"{name} 이라는 도구는 없다"}

    except BudgetExceeded as e:
        return {
            "status": "budget_exceeded",
            "message": e.message,
            "instruction": "이번 요청의 조회 한도에 걸렸다. 도구를 더 부르지 말고 "
            "지금까지 결과로 답하고, 일부만 확인했다는 것을 밝혀라.",
        }
    except QuotaExceeded as e:
        return {
            "status": "quota_exceeded",
            "message": e.message,
            "instruction": "이 조회는 오늘 더 못 한다. 다시 부르지 말고 남은 정보로 답하고, "
            "확인하지 못한 부분은 못 했다고 밝혀라.",
        }
    except Exception as e:
        return {"status": "upstream_error", "message": str(e)[:200]}
