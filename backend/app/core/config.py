from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BASE_DIR / ".env", env_file_encoding="utf-8", extra="ignore"
    )

    data_go_kr_service_key: str = ""
    tourapi_mobile_app: str = "tour"

    naver_search_client_id: str = ""
    naver_search_client_secret: str = ""

    llm_base_url: str = ""
    llm_api_key: str = ""
    llm_model: str = "gpt-4o-mini"
    llm_model_light: str = "gpt-4o-mini"
    llm_price_in_1m: float = 0.075
    llm_price_out_1m: float = 0.30

    llm_reasoning_effort: str = "low"
    llm_max_tokens_tool: int = 1000
    llm_max_tokens_compose: int = 1500

    llm_temperature_tool: float = 0.0
    llm_temperature_compose: float = 0.4
    llm_timeout: int = 20
    optimizer_timeout: float = 2.5
    overview_max_chars: int = 1000

    embedding_provider: str = "ollama"
    embedding_base_url: str = "http://127.0.0.1:11434"
    embedding_model: str = "qwen3-embedding:0.6b"
    embedding_api_key: str = ""
    embedding_dim: int = 1024
    similarity_min: float = 0.5

    jwt_secret: str = ""
    jwt_access_ttl: int = 1800
    jwt_refresh_ttl: int = 1209600

    admin_login_id: str = "admin"
    admin_password: str = ""
    allow_dev_login: bool = False

    kakao_client_id: str = ""
    kakao_client_secret: str = ""
    kakao_app_id: str = ""
    kakao_admin_key: str = ""

    database_url: str = "postgresql://tour:tour@localhost:5432/tour"
    report_tz: str = "Asia/Seoul"
    tarrltetar_base_ym: str = "202504"
    crowd_max_days: int = 28
    crowd_page_size: int = 1000
    visitor_lag_days: int = 75
    visitor_weeks_max: int = 12
    trend_weeks: int = 8

    upstream_cache_enabled: bool = True
    upstream_cache_ttl_detail: int = 300
    upstream_cache_ttl_crowd: int = 600
    max_upstream_calls_per_request: int = 40
    request_map_budget: int = 5
    max_tool_rounds: int = 4
    crowd_threshold_high: float = 70.0
    crowd_threshold_low: float = 40.0
    recent_attractions_limit: int = 20
    daily_upstream_quota: int = 1000
    max_sessions_per_user: int = 30
    context_raw_turns: int = 6
    # 목록·대안 카드에 혼잡도·거리·반려동물 값을 같이 내려줄지. 끄면 카드 응답은 예전 모양 그대로다.
    card_extras: bool = False

    rate_anon_per_min: int = 30
    rate_user_per_min: int = 60
    rate_chat_per_min: int = 10
    trust_forwarded_for: bool = False
    cors_origins: str = "http://localhost:5173"

    @property
    def checkpoint_file(self) -> Path:
        return BASE_DIR / "tour_test.checkpoint.json"

    @property
    def cors_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def llm_enabled(self) -> bool:
        return bool(self.llm_api_key)


settings = Settings()
