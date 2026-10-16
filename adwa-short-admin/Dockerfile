# ─────────────────────────────────────────────────────────────
# ADWA SHORT Admin — Multi-stage Dockerfile
# Stage 1: build the Vite bundle with Node
# Stage 2: serve the static files with nginx
# ─────────────────────────────────────────────────────────────

# ---- Stage 1: build ----
FROM node:20-alpine AS build
WORKDIR /app

# Install deps (cache layer)
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund

# Copy source & build
COPY . .
# Override API base URL at build time if needed
ARG VITE_API_BASE_URL=
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
RUN npm run build

# ---- Stage 2: serve ----
FROM nginx:1.27-alpine AS serve
WORKDIR /usr/share/nginx/html

# Static assets
COPY --from=build /app/dist /usr/share/nginx/html

# Nginx config (SPA fallback + /api proxy)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
