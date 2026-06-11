"""Registo de utilização (auditoria) e verificação de quotas diárias."""
from fastapi import HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.rate_limit import client_ip
from app.core.redis import get_redis
from app.db.models import UsageLog


async def log_action(
    db: AsyncSession,
    action: str,
    user_id: str | None = None,
    detail: str | None = None,
    request: Request | None = None,
) -> None:
    log = UsageLog(
        user_id=user_id,
        action=action,
        detail=detail,
        ip_address=client_ip(request) if request else None,
        user_agent=(request.headers.get("user-agent", "")[:512] if request else None),
    )
    db.add(log)
    await db.commit()


async def check_daily_quota(user_id: str, is_premium: bool) -> None:
    """Premium é ilimitado; free tem limite diário contado em Redis."""
    if is_premium:
        return
    settings = get_settings()
    key = f"quota:translations:{user_id}"
    redis = get_redis()
    try:
        count = await redis.incr(key)
        if count == 1:
            await redis.expire(key, 60 * 60 * 24)
    except Exception:
        return
    if count > settings.free_daily_translation_limit:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail="Limite diário do plano gratuito atingido. Atualize para Premium para traduções ilimitadas.",
        )
