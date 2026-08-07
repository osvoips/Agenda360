from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def _ensure_asyncpg_scheme(url: str) -> str:
    """Forces the async driver scheme, no matter how the URL is provided.

    Postgres URLs coming from environment variables (e.g. Railway's managed
    Postgres plugin) are typically plain `postgresql://` or `postgres://`,
    which resolve to the sync psycopg2 driver. SQLAlchemy's async engine
    requires an async driver, so we normalize the scheme to
    `postgresql+asyncpg://` here regardless of what was configured.
    """
    if url.startswith("postgresql+asyncpg://"):
        return url
    if url.startswith("postgresql://"):
        return "postgresql+asyncpg://" + url[len("postgresql://") :]
    if url.startswith("postgres://"):
        return "postgresql+asyncpg://" + url[len("postgres://") :]
    if url.startswith("postgresql+psycopg2://"):
        return "postgresql+asyncpg://" + url[len("postgresql+psycopg2://") :]
    return url


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Role restrita (agenda360_app) — usada pela API em tempo de execução, sujeita a RLS.
    database_url: str = "postgresql+asyncpg://agenda360_app:agenda360_app@localhost:5432/agenda360"
    # Role dona do schema — só para migrations e seed, nunca para servir requisições.
    admin_database_url: str = "postgresql+asyncpg://agenda360:agenda360@localhost:5432/agenda360"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 480

    @field_validator("database_url", "admin_database_url")
    @classmethod
    def _normalize_db_url(cls, value: str) -> str:
        return _ensure_asyncpg_scheme(value)


@lru_cache
def get_settings() -> Settings:
    return Settings()
