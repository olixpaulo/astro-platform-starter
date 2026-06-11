#!/usr/bin/env bash
# GlobalTranslate — script de instalação para desenvolvimento.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "🌍 GlobalTranslate — instalação"

# --- Verificações ---
command -v docker >/dev/null || { echo "❌ Docker não encontrado. Instale: https://docs.docker.com/get-docker/"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "❌ Docker Compose v2 não encontrado."; exit 1; }

# --- .env ---
if [ ! -f .env ]; then
  cp .env.example .env
  if command -v openssl >/dev/null; then
    SECRET=$(openssl rand -hex 32)
    sed -i.bak "s|^SECRET_KEY=.*|SECRET_KEY=${SECRET}|" .env && rm -f .env.bak
    PG_PASS=$(openssl rand -hex 16)
    sed -i.bak "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${PG_PASS}|" .env && rm -f .env.bak
    echo "✅ .env criado com SECRET_KEY e POSTGRES_PASSWORD gerados"
  else
    echo "⚠️  .env criado a partir do exemplo — defina SECRET_KEY e POSTGRES_PASSWORD manualmente"
  fi
  echo "⚠️  Defina OPENAI_API_KEY no .env antes de usar tradução"
else
  echo "ℹ️  .env já existe — mantido"
fi

# --- Backend (ambiente local opcional para testes) ---
if command -v python3 >/dev/null; then
  echo "📦 A preparar ambiente Python para testes…"
  python3 -m venv backend/.venv
  backend/.venv/bin/pip install -q -r backend/requirements.txt -r backend/requirements-dev.txt
  echo "✅ Testes: cd backend && .venv/bin/python -m pytest"
fi

# --- Frontend ---
if command -v flutter >/dev/null; then
  echo "📦 flutter pub get…"
  (cd frontend && flutter pub get)
else
  echo "ℹ️  Flutter não encontrado — instale https://docs.flutter.dev/get-started para o frontend"
fi

echo ""
echo "🚀 Arrancar a stack:    docker compose up -d --build"
echo "   API:                http://localhost:8000/docs"
echo "   Painel admin:       http://localhost:8000/admin/panel"
echo "   Criar admin:        ./scripts/create_admin.sh admin@example.com 'SenhaForte123!'"
