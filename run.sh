#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="expense_tracking_2.0"
PORT="8080"
ENV_FILE=".env"

echo "🐳 Checking for local Docker image: ${IMAGE_NAME}"

# --- Ensure .env exists ---
if [ ! -f "${ENV_FILE}" ]; then
  echo "📝 Creating ${ENV_FILE}"
  touch "${ENV_FILE}"
fi

# --- Ensure SECRET_KEY_BASE exists ---
if ! grep -q "^SECRET_KEY_BASE=" "${ENV_FILE}"; then
  echo "🔐 SECRET_KEY_BASE not found. Generating one..."
  SECRET_KEY_BASE=$(openssl rand -hex 64)
  echo "SECRET_KEY_BASE=${SECRET_KEY_BASE}" >> "${ENV_FILE}"
  echo "✅ SECRET_KEY_BASE written to ${ENV_FILE}"
else
  echo "🔐 SECRET_KEY_BASE already present"
fi

# --- Optional: warn if APP_SECRET missing ---
if ! grep -q "^APP_SECRET=" "${ENV_FILE}"; then
  echo "⚠️  APP_SECRET not set in ${ENV_FILE} (continuing anyway)"
fi

# --- Build image only if missing locally ---
if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "🔨 Image not found locally. Building it now..."
  docker compose build
else
  echo "✅ Image already exists locally. Skipping build."
fi

# --- Start app ---
echo "🚀 Starting app with docker compose..."
docker compose up -d

# --- Determine IP (portable) ---
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ipconfig getifaddr en0 2>/dev/null || echo "localhost")

echo ""
echo "🎉 App is running!"
echo ""
echo "➡️  Connect from this machine:"
echo "    http://localhost:${PORT}"
echo ""
echo "➡️  Connect from another device on your network:"
echo "    http://${LOCAL_IP}:${PORT}"
echo ""