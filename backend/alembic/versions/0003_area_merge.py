"""전남광주통합특별시 통합 반영. area_codes.legacy_cd 추가, 옛 코드로 쌓인 행을 새 코드로 옮긴다.

2026년 광주광역시(29)·전라남도(46)가 전남광주통합특별시(12)로 합쳐지면서 관광정보·방문자수
API 의 시군구 코드가 12xxx 로 바뀌었다. 이름 매핑, 벡터, 최근 본 관광지, 방문자수 테이블에
옛 코드로 쌓인 행을 새 코드로 옮겨 다시 받지 않게 한다. area_codes 의 옛 시도 행은 지우고,
새 행은 기동 시 코드표 갱신(area.ensure_loaded)이 관광정보 코드표에서 다시 받는다.

Revision ID: 0003
Revises: 0002
Create Date: 2026-09-17
"""
from __future__ import annotations

from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None

# 옛 코드 -> 새 코드. app.services.area.LEGACY_CODES 를 뒤집은 표.
RENAMED = {
    "29110": "12210", "29140": "12240", "29155": "12270", "29170": "12300", "29200": "12330",
    "46110": "12110", "46130": "12130", "46150": "12150", "46170": "12170", "46230": "12190",
    "46710": "12710", "46720": "12720", "46730": "12730", "46770": "12740", "46780": "12750",
    "46790": "12760", "46800": "12770", "46810": "12780", "46820": "12790", "46830": "12800",
    "46840": "12810", "46860": "12820", "46870": "12830", "46880": "12840", "46890": "12850",
    "46900": "12860", "46910": "12870",
}

# (테이블, 코드 열, 코드와 함께 키가 되는 열). 키 열이 있으면 새 코드로 같은 키가 이미 있는 옛 행은 버린다.
TABLES = [
    ("attraction_name_map", "signgu_cd", ["tats_nm"]),
    ("attraction_vectors", "signgu_cd", []),
    ("recent_attractions", "signgu_cd", []),
    ("visitor_daily", "signgu_cd", ["day"]),
]


def move(table: str, col: str, keys: list[str], src: str, dst: str) -> None:
    if keys:
        same = " AND ".join(f"n.{k} = t.{k}" for k in keys)
        op.execute(
            f"DELETE FROM {table} t WHERE t.{col} = '{src}' AND EXISTS "
            f"(SELECT 1 FROM {table} n WHERE n.{col} = '{dst}' AND {same})"
        )
    op.execute(f"UPDATE {table} SET {col} = '{dst}' WHERE {col} = '{src}'")


def upgrade() -> None:
    op.execute("ALTER TABLE area_codes ADD COLUMN IF NOT EXISTS legacy_cd TEXT")
    for table, col, keys in TABLES:
        for old, new in RENAMED.items():
            move(table, col, keys, old, new)
    op.execute("DELETE FROM area_codes WHERE area_cd IN ('29', '46')")


def downgrade() -> None:
    for table, col, keys in TABLES:
        for old, new in RENAMED.items():
            move(table, col, keys, new, old)
    op.drop_column("area_codes", "legacy_cd")
