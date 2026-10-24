# ADWA SHORT · Admin Console

> Premium streaming-service operations dashboard for the ADWA SHORT platform.
> Built with **React 19**, **Vite 8**, **Tailwind CSS v4**, **React Query**, **Zustand**, **Recharts** (plain JavaScript).
> Cinematic black + blood-red + white brand identity. Desktop-first.

---

## 1. Overview

This is the admin/operations console for ADWA SHORT — the Ethiopian short-video streaming
platform. It lets operators:

- Manage the **content catalog** (series, shorts, episodes, categories, posters, video uploads)
- Configure **monetization** (coin packages, time passes, subscriptions, ad-unlock rule, loyalty)
- Operate the **walk-in center** — search a user, receive cash, top-up wallet, print a receipt
- Inspect **users** (wallet, devices, subscriptions, watch history, ban/unban)
- Watch **analytics** (overview KPIs, content performance, retention cohorts)
- Tune **platform settings** (max devices, free trial, coin price, maintenance mode)

The dashboard is designed to look and feel like a premium streaming-service ops console —
Netflix Partner Hub meets Stripe Dashboard. Dense, dark, with blood-red highlights for CTAs and
active states.

---

## 2. Prerequisites

- **Node.js 20+** (Node 22 LTS recommended)
- **npm 10+** (or `pnpm`/`yarn` — this README uses `npm`)
- **The ADWA SHORT backend** running on `http://localhost:8000`
  (see `adwa-short-backend/README.md` for setup)

Verify Node:

```bash
node --version   # v20.x or higher
npm --version    # 10.x or higher
```

---

## 3. Configuration

### `.env`

Copy the example and edit as needed:

```bash
cp .env.example .env
```

```dotenv
# Browser-facing API base URL. Empty in dev → uses Vite proxy (recommended).
VITE_API_BASE_URL=

# Vite dev-server proxy target (server-side, never exposed to the browser)
VITE_API_PROXY_TARGET=http://localhost:8000
```

### How the Vite proxy works

In **development** (`npm run dev`), leave `VITE_API_BASE_URL` empty. The Axios client uses the
base path `/api`, which Vite's dev server proxies to `http://localhost:8000` (configurable via
`VITE_API_PROXY_TARGET`). This avoids CORS issues entirely — the browser only talks to
`http://localhost:5173`.

In **production** (`npm run build`), set `VITE_API_BASE_URL` to the deployed backend URL (e.g.
`https://api.adwashort.et`) at build time:

```bash
VITE_API_BASE_URL=https://api.adwashort.et npm run build
```

The bundle's Axios client will then hit `${VITE_API_BASE_URL}/api/...` directly. Make sure CORS
is configured on the backend to allow your admin domain.

---

## 4. Install

```bash
npm install
```

> **Tailwind v4 note**: This project uses `tailwindcss@4.3` + `@tailwindcss/vite`. There is **no
> `tailwind.config.js`** — all theme tokens are declared in `src/index.css` via the `@theme`
> directive (see §11). The Vite plugin is enabled in `vite.config.js`.

---

## 5. Run dev server

```bash
npm run dev
```

Opens at **http://localhost:5173**. Sign in with the default admin credentials (see §13).

Hot-reload is enabled. Edits to `src/` reload instantly.

---

## 6. Build for production

```bash
npm run build
```

Produces a minified bundle in `dist/` (Vite handles the entire build — no separate type-check
step). The build runs `vite build` directly.

For an environment-specific build:

```bash
VITE_API_BASE_URL=https://api.adwashort.et npm run build
```

---

## 7. Preview the build

```bash
npm run preview
```

Serves `dist/` on `http://localhost:4173` — useful for a final smoke-test before deploying.

---

## 8. Test

```bash
npm run test        # one-shot
npm run test:watch  # watch mode
```

Tests use **Vitest** + **@testing-library/react** + **jsdom**. Config is in `vite.config.js`
(`test` block). Setup file: `src/test-setup.js`.

---

## 9. Lint

```bash
npm run lint
```

Uses **ESLint 9** flat config (`eslint.config.js`) with `@eslint/js` recommended rules +
React Hooks + React Refresh plugins. Targets plain JavaScript (`*.js` / `*.jsx`).

---

## 10. Code structure

```
adwa-short-admin/
├── public/                   # static assets (favicon.svg, logo.svg)
├── src/
│   ├── main.jsx              # React 19 root: createRoot + QueryClient + Toaster + Router
│   ├── App.jsx               # RouterProvider mount
│   ├── index.css             # Tailwind v4 @import + @theme tokens + base layer
│   ├── lib/
│   │   ├── api.js            # Axios instance, Bearer + X-Device-Id interceptors, 401 refresh
│   │   ├── queryClient.js    # React Query client config
│   │   ├── store.js          # Zustand auth store (user, tokens, login/logout) + persist
│   │   ├── hooks.js          # All React Query hooks (useUsers, useSeriesList, ...)
│   │   ├── cn.js             # clsx + tailwind-merge
│   │   └── format.js         # Birr / date / number / duration formatters
│   ├── components/
│   │   ├── layout/           # AdminLayout, Sidebar, Topbar, ProtectedRoute
│   │   ├── ui/               # Button, Input, Select, Card, Modal, Table, Tabs,
│   │   │                     #   Pagination, StatCard, EmptyState, ConfirmDialog,
│   │   │                     #   ToastProvider, FileDropzone, Badge
│   │   ├── charts/           # AreaChartCard, BarChartCard, DonutChartCard, MiniSparkline
│   │   └── content/          # SeriesForm, EpisodeForm, CategoryForm, CoinPackageForm,
│   │                         #   PassForm, SubscriptionPlanForm
│   ├── pages/
│   │   ├── Login.jsx
│   │   ├── Dashboard.jsx
│   │   ├── NotFound.jsx
│   │   ├── content/          # SeriesList, SeriesCreate, SeriesEdit, Episodes
│   │   ├── categories/       # Categories
│   │   ├── monetization/     # CoinPackages, TimePasses, Subscriptions, AdUnlockRule, LoyaltyConfig
│   │   ├── users/            # UsersList, UserDetail
│   │   ├── walkin/           # ManualDeposit (walk-in center)
│   │   ├── settings/         # Settings
│   │   └── analytics/        # ContentPerformance, Retention
│   └── routes/
│       └── index.jsx         # React Router 7 route tree
├── index.html
├── vite.config.js            # Vite 8 + React plugin + @tailwindcss/vite + /api proxy + vitest
├── package.json
├── eslint.config.js          # ESLint 9 flat config (JS + JSX)
├── .env.example
├── Dockerfile                # multi-stage: node build → nginx serve
└── nginx.conf                # SPA fallback + /api proxy
```

### Page count

- **Auth**: 1 (Login)
- **Layout**: 1 (AdminLayout wraps all below)
- **Dashboard**: 1
- **Content**: 4 (SeriesList, SeriesCreate, SeriesEdit, Episodes)
- **Categories**: 1
- **Monetization**: 5 (CoinPackages, TimePasses, Subscriptions, AdUnlockRule, LoyaltyConfig)
- **Users**: 2 (UsersList, UserDetail)
- **Walk-in**: 1 (ManualDeposit)
- **Analytics**: 2 (ContentPerformance, Retention)
- **Settings**: 1
- **Errors**: 1 (NotFound)
- **Total: 20 distinct page components** (plus reusable form/modal components)

---

## 11. Brand identity & Tailwind v4 setup

The dashboard uses a strict **black / blood-red / white** palette:

| Token              | Hex       | Usage                                   |
| ------------------ | --------- | --------------------------------------- |
| `--color-base`     | `#0A0A0A` | App background (cinematic black)        |
| `--color-surface`  | `#141414` | Cards, panels                           |
| `--color-surface-2`| `#1F1F1F` | Inputs, hover, secondary surfaces       |
| `--color-surface-3`| `#2A2A2A` | Strong hover, table headers             |
| `--color-border`   | `#2A2A2A` | Default borders                         |
| `--color-accent`   | `#C8102E` | Blood red — CTAs, active states         |
| `--color-accent-hover` | `#A00D24` | Hover state for blood red           |
| `--color-text-primary` | `#FFFFFF` | Primary text                        |
| `--color-text-secondary`| `#A3A3A3` | Secondary text                      |
| `--color-success`  | `#10B981` | Positive deltas, active badges          |
| `--color-warning`  | `#F59E0B` | Pending, exclusive, warnings            |
| `--color-danger`   | `#DC2626` | Destructive actions (use accent mostly) |

### How Tailwind v4 differs from v3

- **No `tailwind.config.js`** — all theme tokens live in `src/index.css` via the `@theme` directive
- Vite plugin `@tailwindcss/vite` scans your source files automatically
- All tokens above become Tailwind utilities: `bg-base`, `bg-surface`, `bg-accent`,
  `text-text-primary`, `border-border`, `text-accent`, etc.
- Custom CSS lives in `@layer components` (see `.input-base`, `.card-surface`)

Example from `src/index.css`:

```css
@import "tailwindcss";

@theme {
  --color-base: #0a0a0a;
  --color-surface: #141414;
  --color-accent: #c8102e;
  --color-accent-hover: #a00d24;
  --color-text-primary: #ffffff;
  --color-text-secondary: #a3a3a3;
  --color-border: #2a2a2a;
  --font-sans: "Inter", system-ui, sans-serif;
}
```

---

## 12. Backend dependency

The dashboard has no mock layer — every screen calls the real ADWA SHORT backend.
**Start the backend first.**

```bash
cd ../adwa-short-backend
# see backend README for full instructions
uvicorn app.main:app --reload --port 8000
```

API contract mirrors `adwa-short-backend` exactly. See `src/lib/hooks.js` for the React Query
wrappers — each hook corresponds to a backend endpoint.

---

## 13. Default admin login

| Field    | Value             |
| -------- | ----------------- |
| Phone    | `+251900000000`   |
| Password | `admin123`        |

The credentials are seeded by the backend on first boot. **Change them immediately** after your
first login (via the backend admin script or by replacing the seeded record).

---

## 14. Walk-in Center workflow

The walk-in center is the headline feature for the physical walk-in office. Find it under
**Users → Walk-in Deposit** in the sidebar (or navigate to `/walkin/manual-deposit`).

### Step-by-step

1. **Search the user** — by phone number, full name, or User ID. The system returns a list of
   matching users with their current wallet balance.
2. **Select the user** — click to confirm. The user card highlights in red and Step 2 unlocks.
3. **Enter cash received** — type the Birr amount the customer handed over. The dashboard
   auto-suggests the coin equivalent based on the `coin_price_birr` setting (Settings → Pricing).
   Adjust the coin amount in the optional field if needed.
4. **Add a note** (optional) — e.g. *"Customer paid cash at office, 2025-10-08 · receipt #1234"*.
5. **Click "Top-Up Wallet"** — the dashboard calls `POST /admin/wallet/manual-deposit`. The user's
   wallet is credited in real time, and a **printable receipt** appears.
6. **Print the receipt** — the receipt has a clean black-on-white layout that prints well on
   standard A4/thermal printers. Click **Print** or close the modal.

Below the workflow you'll find a **Recent Manual Deposits** table showing the last deposits
processed at the office (user, amount, coins, admin who processed it, timestamp, notes).

---

## 15. Deployment

### Static hosting (Vercel / Netlify / Nginx / S3+CloudFront)

The build output is a static bundle in `dist/`. Any static host works.

1. Build with the correct API URL:
   ```bash
   VITE_API_BASE_URL=https://api.adwashort.et npm run build
   ```
2. Upload the contents of `dist/` to your host's web root.
3. Configure **SPA fallback**: every unknown route should serve `index.html` so React Router can
   pick it up client-side.

#### Nginx example (SPA fallback)

```nginx
location / {
  try_files $uri $uri/ /index.html;
}

location /api/ {
  proxy_pass http://adwa-backend:8000/;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  client_max_body_size 200M;  # video uploads
}
```

The included `nginx.conf` already does both. See §Docker below.

### Environment-specific builds

Because Vite inlines env vars at build time, produce a separate bundle per environment:

```bash
# Staging
VITE_API_BASE_URL=https://api.staging.adwashort.et npm run build
# → upload to staging host

# Production
VITE_API_BASE_URL=https://api.adwashort.et npm run build
# → upload to production host
```

### Docker

A multi-stage `Dockerfile` is included:

```bash
# Build & serve with the bundled nginx.conf (proxies /api → adwa-backend:8000)
docker build -t adwa-short-admin .

# Run
docker run -p 8080:80 adwa-short-admin
# → http://localhost:8080
```

For a different backend host, edit `nginx.conf`'s `proxy_pass` line (or template it via
`envsubst`). For a different API base URL baked into the bundle, pass a build arg:

```bash
docker build --build-arg VITE_API_BASE_URL=https://api.adwashort.et -t adwa-short-admin .
```

The included `nginx.conf` is production-ready: gzip, security headers, long-cache static assets,
SPA fallback, and a generous `client_max_body_size` for video uploads.

---

## 16. Troubleshooting

### CORS errors in the browser console

**Cause**: `VITE_API_BASE_URL` is set (non-empty) in dev and the backend's CORS allowlist doesn't
include `http://localhost:5173`.

**Fix**: Either leave `VITE_API_BASE_URL` empty in dev (use the Vite proxy), or add
`http://localhost:5173` to the backend's `CORS_ORIGINS` env var.

### "Session expired" toast / loops back to Login

**Cause**: The refresh token has expired or been revoked.

**Fix**: Sign in again. The Axios interceptor will attempt a token refresh once on 401; if that
fails it clears the auth store and redirects to `/login`.

### Upload fails with 413 Payload Too Large

**Cause**: The reverse proxy or backend limits the request body size below the file size.

**Fix**: Raise `client_max_body_size` in nginx (the bundled config uses `200M`) and the backend's
equivalent (e.g. uvicorn / FastAPI upload size). For very large videos, prefer a direct-to-storage
upload flow.

### Charts render but data is empty

**Cause**: The backend's analytics endpoints return empty arrays until the platform has real
traffic. This is expected on a fresh install. Add some test data (users, episodes, views) and the
charts will populate.

### `npm install` fails on Linux

Some `esbuild` / `@tailwindcss/vite` binaries need `python3` and `make` available. On a minimal
Alpine:

```bash
apk add python3 make g++
```

### Tailwind classes don't apply

Make sure you're on **Tailwind v4** (`tailwindcss@4.3.x`), not v3. v3 expects a
`tailwind.config.js`; v4 doesn't. Verify with `npm ls tailwindcss`.

### Build cache issues

If a previous build left stale artifacts, clear them and rebuild:

```bash
rm -rf node_modules/.vite dist
npm run build
```

---

## 17. License & ownership

© 2025 Adwa Studios. All rights reserved.
This is an internal operations tool — not for public distribution.
