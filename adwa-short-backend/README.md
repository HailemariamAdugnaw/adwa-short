# ADWA SHORT — Backend (FastAPI)

Production-ready FastAPI backend for the ADWA SHORT video streaming platform. Serves both the Flutter mobile app and the React admin dashboard.

## Stack
- Python 3.11+
- FastAPI 0.142.4
- PostgreSQL 18.6 (asyncpg + SQLAlchemy 2.x async)
- JWT auth (PyJWT)
- Alembic for migrations
- Pydantic v2 + pydantic-settings
- passlib[bcrypt] for password hashing

## Quick Start (local)

```bash
# 1. Create venv & install deps
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt

# 2. Configure env
cp .env.example .env
# edit DATABASE_URL + JWT_SECRET as needed

# 3. Run migrations (Postgres) or use create_all shortcut
alembic upgrade head
# (or just run the app once with create_all via: python -c "import asyncio; from app.database import create_all; asyncio.run(create_all())")

# 4. Seed demo data
python -m app.seed

# 5. Run the API
uvicorn app.main:app --reload --port 8000
```

Visit `http://localhost:8000/docs` for OpenAPI docs.

### Seeded accounts
- Admin: `+251900000000` / `admin123`
- Demo user: `+251911111111` / `user123`

## Docker Compose

```bash
docker compose up --build
```
This starts PostgreSQL 18 and the API on port 8000. After the stack is up, run migrations + seed:
```bash
docker compose exec api alembic upgrade head
docker compose exec api python -m app.seed
```

## Env vars

| Var | Default | Notes |
|---|---|---|
| `DATABASE_URL` | `postgresql+asyncpg://adwa:adwa@localhost:5432/adwa_short` | async SQLAlchemy DSN |
| `JWT_SECRET` | `change-me-in-production` | signing secret |
| `JWT_ALG` | `HS256` | |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `60` | |
| `REFRESH_TOKEN_EXPIRE_DAYS` | `30` | |
| `UPLOAD_DIR` | `./uploads` | file upload root |
| `CORS_ORIGINS` | `http://localhost:5173,http://localhost:8080` | comma-separated |
| `MAX_DEVICES_PER_ACCOUNT` | `2` | default, also overridable via AppSettings |

## Endpoint Summary

### Auth
| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/auth/register` | — | phone + password |
| POST | `/auth/login` | — | requires `X-Device-Id` header |
| POST | `/auth/refresh` | — | body: `{refresh_token}` |
| POST | `/auth/logout` | user | stateless JWT |

### Users / Devices
| GET | `/users/me` | user | |
| PUT | `/users/me` | user | update profile |
| GET | `/users/{id}` | admin | |
| POST | `/devices/register` | user | |
| GET | `/devices` | user | |
| DELETE | `/devices/{id}` | user | |

### Content (public read, admin write)
| GET | `/categories` | — | |
| POST/PUT/DELETE | `/categories[/{id}]` | admin | |
| GET | `/series` | — | filters: `category_id`, `is_vip`, `is_short` |
| GET | `/series/{id}` | optional user | includes episodes |
| POST/PUT/DELETE | `/series[/{id}]` | admin | |
| GET | `/episodes` | — | filters: `series_id`, `is_short` |
| GET | `/episodes/{id}` | — | |
| GET | `/episodes/{id}/access` | optional user | returns free/allowed/denied + reason |
| POST | `/episodes/{id}/unlock` | user | deduct coins |
| POST/PUT/DELETE | `/episodes[/{id}]` | admin | |
| GET | `/shorts/feed` | — | vertical video feed |
| GET | `/shelves/home` | — | full shelf collection (Hot&New, Trending, MostSeen, FrequentSeen, MostSearched, Popular, MostViral, VIP, Exclusive, genre shelves) |
| GET | `/search?q=` | optional user | logs the query |
| GET | `/search/popular` | — | |
| GET | `/search/most-searched` | — | |

### Engagement (user auth)
| POST | `/engagement/view` | user | |
| POST | `/engagement/like` | user | toggle |
| POST | `/engagement/comment` | user | |
| GET | `/engagement/comments/{episode_id}` | — | |
| POST | `/engagement/save` | user | |
| DELETE | `/engagement/save/{episode_id}` | user | |
| GET | `/engagement/history` | user | |
| GET | `/engagement/saved` | user | |

### Wallet / Coins (user auth)
| GET | `/wallet` | user | |
| GET | `/wallet/transactions` | user | |
| POST | `/wallet/deposit` | user | telebirr/bank stub |
| GET | `/coins/packages` | — | |
| POST | `/coins/purchase` | user | deducts Birr, credits coins |
| POST | `/coins/spend` | user | unlock episode with coins |
| POST/PUT/DELETE | `/coins/packages[/{id}]` | admin | |

### Time Passes + Subscriptions
| GET | `/passes` | — | |
| GET | `/passes/my` | user | |
| POST | `/passes/purchase` | user | |
| POST/PUT/DELETE | `/passes[/{id}]` | admin | |
| GET | `/subscriptions/plans` | — | |
| GET | `/subscriptions/my` | user | |
| POST | `/subscriptions/subscribe` | user | |
| POST | `/subscriptions/cancel/{id}` | user | |
| POST/PUT/DELETE | `/subscriptions/plans[/{id}]` | admin | |

### Ad-unlock + Loyalty
| GET | `/ad-unlocks/rule` | — | |
| PUT | `/ad-unlocks/rule` | admin | |
| POST | `/ad-unlocks/watched` | user | unlock episode by watching ads |
| GET | `/loyalty/config` | admin | |
| PUT | `/loyalty/config` | admin | |
| GET | `/loyalty/my-grants` | user | |
| GET | `/loyalty/grants/{user_id}` | admin | |

### Settings
| GET | `/settings/public` | — | public subset |
| GET | `/settings` | admin | all key/value |
| GET/PUT | `/settings/{key}` | admin (PUT) | |

### Uploads (admin)
| POST | `/uploads/poster` | admin | multipart |
| POST | `/uploads/video` | admin | multipart (max 1GB) |
Files are served statically under `/uploads/...`

### Admin
| GET | `/admin/content/unpublished` | admin | |
| POST | `/admin/content/series/{id}/publish` | admin | |
| POST | `/admin/content/series/{id}/unpublish` | admin | |
| POST | `/admin/content/episodes/{id}/publish` | admin | |
| POST | `/admin/content/episodes/{id}/unpublish` | admin | |
| GET | `/admin/content/audit` | admin | audit log |
| POST | `/admin/content/analytics/recompute` | admin | refresh popular_score |
| GET | `/admin/users` | admin | search `?q=` |
| GET/PUT | `/admin/users/{id}` | admin | adjust wallet / ban / role |
| POST | `/admin/users/{id}/ban` | admin | |
| POST | `/admin/users/{id}/unban` | admin | |
| POST | `/admin/wallet/manual-deposit` | admin | walk-in cash |
| GET | `/admin/wallet/manual-deposits` | admin | |
| GET | `/admin/analytics/overview` | admin | KPIs |
| GET | `/admin/analytics/content` | admin | top content |
| GET | `/admin/analytics/revenue?days=30` | admin | |
| GET | `/admin/analytics/retention` | admin | cohort D1/D7/D30 |

## Monetization Resolution
For any episode the server follows this priority (`app/services/monetization.py`):
1. `episode_number <= series.free_episode_count` → FREE
2. user has ad-unlock log for this episode → ALLOWED_AD
3. user has active time pass → ALLOWED_PASS
4. user has active subscription → ALLOWED_SUBSCRIPTION
5. `coin_cost > 0` and wallet has enough coins → ALLOWED_COINS (deducts)
6. else → BLOCKED with reason `need_ad` | `need_coins` | `need_pass` | `need_subscription`

## Loyalty Engine
After every deposit, the loyalty engine checks the user's Birr balance:
- if `min_balance_birr <= balance_birr <= max_balance_birr`
- and no grant was given in the past 24h
→ grants `free_coins` and logs a `LoyaltyRewardGrant`.

## File Uploads
Saved under `uploads/posters/` and `uploads/videos/`, served via `StaticFiles` at `/uploads`. UUID filenames.

## Tests

```bash
pytest -v
```
Tests use in-memory SQLite (via `aiosqlite`) by default — no external services needed.
Set `TEST_DATABASE_URL` env var to override with a real Postgres DSN for integration tests.

Covers:
- auth flow (register/login/refresh/me)
- device limit enforcement
- content listing + access check
- wallet deposit + coin purchase + manual cash deposit
- admin content publish + audit + user management + settings

## Project layout
See the project structure in the parent spec; all code lives under `app/`, migrations under `alembic/`, tests under `tests/`, uploads under `uploads/`.

## Brand
Default seeded posters/banners use the brand palette: Black `#0A0A0A`, Blood Red `#C8102E`, White `#FFFFFF`.
