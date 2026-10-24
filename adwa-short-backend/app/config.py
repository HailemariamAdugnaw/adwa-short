from __future__ import annotations

from functools import lru_cache
from typing import List

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    DATABASE_URL: str = "postgresql+asyncpg://adwa:adwa@localhost:5432/adwa_short"
    JWT_SECRET: str = "change-me-in-production"
    JWT_ALG: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    UPLOAD_DIR: str = "./uploads"
    CORS_ORIGINS: str = "http://localhost:5173,http://localhost:8080"
    MAX_DEVICES_PER_ACCOUNT: int = 2
    MAX_UPLOAD_SIZE: int = 2 * 1024 * 1024 * 1024

    @field_validator("CORS_ORIGINS")
    @classmethod
    def _strip_cors(cls, v: str) -> str:
        return ",".join([s.strip() for s in v.split(",") if s.strip()])

    @property
    def cors_list(self) -> List[str]:
        return [s.strip() for s in self.CORS_ORIGINS.split(",") if s.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
