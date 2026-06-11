from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "GlobalTranslate"
    environment: str = "development"
    api_v1_prefix: str = "/api/v1"
    cors_origins: str = "http://localhost:3000,http://localhost:8080"

    secret_key: str = "dev-secret-key-do-not-use-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 30
    encryption_key: str = ""

    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_user: str = "globaltranslate"
    postgres_password: str = "globaltranslate"
    postgres_db: str = "globaltranslate"
    database_url_override: str = ""

    redis_url: str = "redis://localhost:6379/0"

    rate_limit_free_per_minute: int = 20
    rate_limit_premium_per_minute: int = 120

    openai_api_key: str = ""
    openai_translation_model: str = "gpt-4o-mini"
    openai_tts_model: str = "tts-1"
    openai_stt_model: str = "whisper-1"
    openai_vision_model: str = "gpt-4o-mini"

    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    email_from: str = "no-reply@globaltranslate.app"

    stripe_api_key: str = ""
    stripe_webhook_secret: str = ""

    upload_dir: str = "uploads"
    max_document_size_free_mb: int = 5
    max_document_size_premium_mb: int = 50
    free_daily_translation_limit: int = 100

    @property
    def database_url(self) -> str:
        if self.database_url_override:
            return self.database_url_override
        return (
            f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
