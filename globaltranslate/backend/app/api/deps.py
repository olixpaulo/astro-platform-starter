"""Dependências FastAPI: utilizador atual, admin, premium, rate limiting."""
from typing import Annotated

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.rate_limit import client_ip, enforce_rate_limit
from app.core.security import ACCESS_TOKEN, decode_token
from app.db.models import PlanTier, Subscription, SubscriptionStatus, User, UserRole
from app.db.session import get_db

bearer_scheme = HTTPBearer(auto_error=False)

DbSession = Annotated[AsyncSession, Depends(get_db)]

_credentials_error = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Credenciais inválidas ou expiradas",
    headers={"WWW-Authenticate": "Bearer"},
)


async def get_current_user(
    db: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> User:
    if credentials is None:
        raise _credentials_error
    try:
        payload = decode_token(credentials.credentials, ACCESS_TOKEN)
    except JWTError:
        raise _credentials_error
    user = await db.get(User, payload["sub"])
    if user is None or not user.is_active:
        raise _credentials_error
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


async def get_current_admin(user: CurrentUser) -> User:
    if user.role != UserRole.admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso restrito a administradores")
    return user


CurrentAdmin = Annotated[User, Depends(get_current_admin)]


async def user_is_premium(db: AsyncSession, user: User) -> bool:
    result = await db.execute(
        select(Subscription)
        .join(Subscription.plan)
        .where(
            Subscription.user_id == user.id,
            Subscription.status == SubscriptionStatus.active,
        )
    )
    for sub in result.scalars():
        if sub.plan.tier in (PlanTier.premium, PlanTier.business):
            return True
    return False


async def rate_limited_user(request: Request, db: DbSession, user: CurrentUser) -> User:
    premium = await user_is_premium(db, user)
    await enforce_rate_limit(request, f"user:{user.id}", is_premium=premium)
    return user


RateLimitedUser = Annotated[User, Depends(rate_limited_user)]


async def rate_limit_anonymous(request: Request) -> None:
    await enforce_rate_limit(request, f"ip:{client_ip(request)}", is_premium=False)
