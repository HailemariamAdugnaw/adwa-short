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

    # Ad Network Configuration (Exclusively Google AdMob)
    AD_ENABLED: bool = True
    AD_TEST_MODE: bool = True
    AD_NETWORK_PROVIDER: str = "admob"
    AD_NETWORK_APP_ID: str = "ca-app-pub-3940256099942544~3347511713"
    AD_REWARDED_UNIT_ID: str = "ca-app-pub-3940256099942544/5224354917"
    AD_INTERSTITIAL_UNIT_ID: str = "ca-app-pub-3940256099942544/1033173712"
    AD_BANNER_UNIT_ID: str = "ca-app-pub-3940256099942544/6300978111"
    AD_NETWORK_API_KEY: str = ""
    AD_REWARD_CALLBACK_SECRET: str = "adwa_ssv_secret_key_change_in_production"
    AD_ADS_REQUIRED: int = 2
    AD_EPISODES_UNLOCKED: int = 1

    # Commercial Bank of Ethiopia (CBE / CBE Birr) Gateway & Webhook Configuration
    CBE_ENABLED: bool = True
    CBE_TEST_MODE: bool = True
    CBE_API_BASE_URL: str = "https://api.cbe.com.et"
    CBE_MERCHANT_ID: str = "CBE_MERCHANT_ADWA_SHORT"
    CBE_TILL_NUMBER: str = "847291"
    CBE_API_KEY: str = "cbe_api_key_adwashort_live"
    CBE_SECRET_KEY: str = "cbe_secret_key_change_in_production"
    CBE_WEBHOOK_SECRET: str = "cbe_webhook_signing_secret_prod"
    CBE_WEBHOOK_URL: str = "https://api.adwashort.com/api/v1/payments/cbe/webhook"
    CBE_RETURN_URL: str = "adwashort://payment-complete"
    CBE_CREATOR_RESERVE_SPLIT_PCT: float = 50.0  # Default % reserved for creator pool from direct CBE purchases

    # Commercial Bank of Ethiopia (CBE) - Platform Treasury Details
    CBE_TREASURY_ACCOUNT_NUMBER: str = "1000293847561"
    CBE_TREASURY_ACCOUNT_NAME: str = "ADWA SHORT ENTERTAINMENT PLATFORM"
    CBE_TREASURY_BANK_NAME: str = "Commercial Bank of Ethiopia (CBE)"
    CBE_TREASURY_BRANCH: str = "Finfine Branch / Head Office"

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
