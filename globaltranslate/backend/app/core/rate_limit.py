"""Rate limiting por utilizador/IP com janela deslizante em Redis."""
import time

from fastapi import HTTPException, Request, status

from app.core.config import get_settings
from app.core.redis import get_redis


async def enforce_rate_limit(request: Request, identity: str, is_premium: bool = False) -> None:
    settings = get_settings()
    limit = settings.rate_limit_premium_per_minute if is_premium else settings.rate_limit_free_per_minute
    key = f"ratelimit:{identity}:{request.url.path}"
    now = time.time()
    window = 60.0

    redis = get_redis()
    try:
        async with redis.pipeline(transaction=True) as pipe:
            pipe.zremrangebyscore(key, 0, now - window)
            pipe.zadd(key, {f"{now}": now})
            pipe.zcard(key)
            pipe.expire(key, 90)
            results = await pipe.execute()
        count = results[2]
    except Exception:
        # Redis indisponível: não bloquear o serviço (fail-open com log a cargo do middleware)
        return

    if count > limit:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Limite de pedidos excedido. Tente novamente em instantes.",
            headers={"Retry-After": "60"},
        )


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"
