#!/usr/bin/env bash
# Cria (ou promove) um utilizador administrador.
# Uso: ./scripts/create_admin.sh email senha
set -euo pipefail

EMAIL="${1:?Uso: $0 <email> <senha>}"
PASSWORD="${2:?Uso: $0 <email> <senha>}"

cd "$(dirname "$0")/.."

docker compose exec -T api python - "$EMAIL" "$PASSWORD" <<'PYEOF'
import asyncio
import sys

from sqlalchemy import select

from app.core.security import hash_password
from app.db.models import User, UserRole
from app.db.session import async_session_factory

email, password = sys.argv[1].lower(), sys.argv[2]


async def main() -> None:
    async with async_session_factory() as db:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user:
            user.role = UserRole.admin
            user.is_active = True
            print(f"Utilizador {email} promovido a admin.")
        else:
            db.add(User(email=email, hashed_password=hash_password(password),
                        full_name="Administrador", role=UserRole.admin, is_verified=True))
            print(f"Admin {email} criado.")
        await db.commit()


asyncio.run(main())
PYEOF
