# ADWA SHORT — Ad Configuration & S2S Webhook Guide

Please refer to the comprehensive [ADS_CONFIGURATION.md](file:///c:/Users/Haile/Documents/adwa-short/ADS_CONFIGURATION.md) for full instructions on configuring ad networks, environment variables, dynamic revenue logging, static fallbacks, and Server-to-Server (S2S) webhooks.

### Quick Summary of Features:

- **Revenue Split**: 100% ADWA SHORT Platform / 0% Content Creator.
- **Dynamic Logging**: If exact impression payout is sent in S2S webhook (e.g., `payout_birr: 0.85`), logs that exact amount.
- **Static Fallbacks**: When live data is absent, falls back to `AD_REWARD_VALUE_BIRR` (0.25 ETB) and `AD_ESTIMATED_CPM_BIRR` (250.0 ETB).
- **S2S Webhook Endpoints**: `POST` / `GET` at `/api/v1/ads/callback` and `/api/v1/ads/postback` (plus `/ad-unlocks/reward-callback`).
- **Admin UI Route**: `/monetization/ad-unlock` (Super Admin Only).
- **Pytest Suite**: `pytest tests/test_ad_configuration.py`.
