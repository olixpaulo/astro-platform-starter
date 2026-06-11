#!/usr/bin/env bash
# Implantação/atualização num VPS (executar no servidor, na raiz do projeto).
set -euo pipefail

cd "$(dirname "$0")/.."

[ -f .env ] || { echo "❌ Falta o .env — copie de .env.example e configure."; exit 1; }

if grep -qE '^SECRET_KEY=change-me' .env; then
  echo "❌ SECRET_KEY ainda é o valor de exemplo. Gere com: openssl rand -hex 32"
  exit 1
fi

echo "📥 git pull…"
git pull --ff-only

echo "🐳 Rebuild e restart…"
docker compose up -d --build

echo "🏥 Health check…"
for i in $(seq 1 30); do
  if curl -fsS http://localhost:8000/health >/dev/null 2>&1; then
    echo "✅ API saudável."
    exit 0
  fi
  sleep 2
done

echo "❌ A API não respondeu ao health check. Logs:"
docker compose logs --tail=50 api
exit 1
