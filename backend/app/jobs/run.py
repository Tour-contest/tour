from __future__ import annotations

import argparse
import asyncio
import json
import logging
import sys

from app.core.config import settings
from app.repository import db
from app.services import area, client, crowding, embedding, matcher, tourapi

log = logging.getLogger("tour.jobs")

CHECKPOINT = settings.checkpoint_file


def load_ckpt() -> dict:
    if CHECKPOINT.exists():
        return json.loads(CHECKPOINT.read_text(encoding="utf-8"))
    return {}


def save_ckpt(data: dict) -> None:
    CHECKPOINT.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")


def spent() -> int:
    return client.quota_used()


async def load_area_codes() -> None:
    await db.init()
    res = await area.load_codes()
    log.info("지역 코드표 %d건 저장 (TourAPI %d, 혼잡도 %d, 코드 불일치 %d)",
             res["saved"], res["tour"], res["crowd"], res["code_differs"])
    if res["tour_unmatched"]:
        log.warning("TourAPI 매칭 실패: %s", ", ".join(res["tour_unmatched"]))


async def crowd_flags(budget: int = 400) -> None:
    await db.init()
    await area.ensure_loaded()
    rows = await db.all_areas()
    ckpt = load_ckpt()
    done = set(ckpt.get("crowd_flags", []))

    checked = 0
    for a in rows:
        if a["crowd_cd"] in done:
            continue
        if spent() >= budget:
            log.warning("할당량 도달, %d/%d 처리", len(done), len(rows))
            break
        try:
            await db.set_crowd_flag(a["crowd_cd"], await crowding.has_data(a["crowd_cd"]))
        except Exception as e:
            log.warning("%s 혼잡도 확인 실패: %s", a["label"], type(e).__name__)
            await db.set_crowd_flag(a["crowd_cd"], False)
        done.add(a["crowd_cd"])
        checked += 1
        if checked % 20 == 0:
            ckpt["crowd_flags"] = sorted(done)
            save_ckpt(ckpt)
            log.info("%d/%d 처리 중", len(done), len(rows))

    ckpt["crowd_flags"] = sorted(done)
    save_ckpt(ckpt)
    await db.promote_parent_crowd_flags()
    stat = await db.crowd_flag_stats()
    log.info("혼잡도 제공 지역 %d, 확인 %d", stat["with"], stat["checked"])


async def build_name_map(codes: list[str], budget: int = 800) -> None:
    await db.init()
    await area.ensure_loaded()

    for code in codes:
        if spent() >= budget:
            log.warning("할당량 도달")
            break
        if "KorService2/searchKeyword2" in client.blocked_ops():
            log.warning("관광지 검색 한도 초과")
            break
        a = await db.get_area(code)
        if a is None:
            log.warning("%s 미등록 지역", code)
            continue
        try:
            by_name = await crowding.fetch_signgu(a["crowd_cd"])
        except Exception as e:
            log.warning("%s 혼잡도 조회 실패: %s", a["label"], type(e).__name__)
            continue
        if not by_name:
            log.info("%s 혼잡도 데이터 없음", a["label"])
            continue

        remain = max(0, budget - spent())
        before = await db.get_mapping(a["crowd_cd"])
        await matcher.ensure(
            a["crowd_cd"], a["tour_cd"], a["signgu_nm"], list(by_name.keys()),
            budget=min(60, remain // 2),
        )
        after = await db.get_mapping(a["crowd_cd"])
        hit = sum(1 for v in after.values() if v.get("content_id"))
        log.info("%-22s %d/%d곳 연결 (+%d), 누적 호출 %d",
                 a["label"], hit, len(by_name), len(after) - len(before), spent())


async def build_vectors(codes: list[str], budget: int = 400) -> None:
    if not await embedding.available():
        log.error("임베딩 사용 불가, ollama 설정 확인 필요")
        return
    await db.init()
    for code in codes:
        if spent() >= budget:
            log.warning("할당량 도달")
            break
        a = await db.get_area(code)
        if a is None:
            continue
        res = await embedding.build_for_area(a["crowd_cd"], a["tour_cd"], limit=80)
        log.info("%-22s 벡터 +%d, 대상 %d", a["label"], res["built"], res.get("total", 0))


async def status() -> None:
    await db.init()
    stat = await db.crowd_flag_stats()
    log.info("지역 코드표 %d건", await db.area_count())
    log.info("혼잡도 제공 %d, 확인 %d", stat["with"], stat["checked"])
    log.info("이름 매핑 %s", await db.mapping_stats())
    log.info("벡터 %s", await db.vector_stats())
    log.info("금일 호출 %d", spent())


async def codes_for(args) -> list[str]:
    if args.all:
        await db.init()
        await area.ensure_loaded()
        rows = await db.all_areas()
        rows.sort(key=lambda r: (r.get("has_crowd_data") is not True, r["crowd_cd"]))
        return [r["crowd_cd"] for r in rows]
    return args.codes or []


async def main() -> None:
    p = argparse.ArgumentParser(prog="jobs")
    p.add_argument("task", choices=["area-codes", "crowd-flags", "name-map", "vectors", "status"])
    p.add_argument("codes", nargs="*", help="시군구 코드 (5자리)")
    p.add_argument("--all", action="store_true", help="전국")
    p.add_argument("--budget", type=int, default=800, help="이번 실행에서 쓸 최대 호출 수")
    args = p.parse_args()

    try:
        if args.task == "area-codes":
            await load_area_codes()
        elif args.task == "crowd-flags":
            await crowd_flags(args.budget)
        elif args.task == "name-map":
            await build_name_map(await codes_for(args), args.budget)
        elif args.task == "vectors":
            await build_vectors(await codes_for(args), args.budget)
        else:
            await status()
    finally:
        await client.flush()
        await client.close_client()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    if not settings.data_go_kr_service_key:
        log.error("DATA_GO_KR_SERVICE_KEY 없음")
        sys.exit(1)
    asyncio.run(main())
