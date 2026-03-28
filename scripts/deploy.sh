#!/usr/bin/env bash
# deploy.sh — runs ON the VPS, called by the GitHub Actions CD job via SSH.
# Usage: ./scripts/deploy.sh <image-tag>
#
# Required environment on the VPS:
#   - Docker + Docker Compose plugin installed
#   - GHCR_TOKEN exported (or logged in via `docker login ghcr.io`)
#   - /opt/pulse/.env file present with all production secrets
#   - /opt/pulse/ contains a checkout of this repo
set -euo pipefail

IMAGE_TAG="${1:-latest}"
APP_DIR="/opt/pulse"

echo "==> [deploy] Starting deployment (tag: ${IMAGE_TAG})"

cd "$APP_DIR"

# ── 1. Pull latest code ───────────────────────────────────────────────────────
echo "==> [deploy] Pulling latest code from origin/main"
git fetch origin main
git reset --hard origin/main
git submodule update --init --recursive

# ── 2. Pull updated images from GHCR ─────────────────────────────────────────
echo "==> [deploy] Pulling Docker images (tag: ${IMAGE_TAG})"
IMAGE_TAG="$IMAGE_TAG" docker compose -f docker-compose.prod.yml pull backend frontend

# ── 3. Zero-downtime rolling restart ─────────────────────────────────────────
# Bring up infrastructure first (postgres, redis) if not already running,
# then rolling-replace the application containers.
echo "==> [deploy] Restarting application containers"
IMAGE_TAG="$IMAGE_TAG" docker compose -f docker-compose.prod.yml up -d \
  --remove-orphans \
  --no-build

# ── 4. Remove dangling images to reclaim disk ─────────────────────────────────
echo "==> [deploy] Pruning dangling images"
docker image prune -f

echo "==> [deploy] Done. Running containers:"
docker compose -f docker-compose.prod.yml ps
