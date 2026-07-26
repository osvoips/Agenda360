from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Role restrita (agenda360_app) — usada pela API em tempo de execução, sujeita a RLS.
    database_url: str = "postgresql+asyncpg://agenda360_app:agenda360_app@localhost:5432/agenda360"
    # Role dona do schema — só para migrations e seed, nunca para servir requisições.
    admin_database_url: str = "postgresql+asyncpg://agenda360:agenda360@localhost:5432/agenda360"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 480


@lru_cache
def get_settings() -> Settings:
    return Settings()
