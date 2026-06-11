from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select

from app.api.deps import DbSession, rate_limit_anonymous
from app.core.config import get_settings
from app.core.security import (
    REFRESH_TOKEN,
    create_access_token,
    create_refresh_token,
    decode_token,
    generate_password_reset_token,
    hash_password,
    hash_token,
    verify_password,
)
from app.db.models import PasswordResetToken, RefreshToken, User
from app.schemas.auth import (
    ForgotPasswordRequest,
    LoginRequest,
    MessageResponse,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenPair,
)
from app.schemas.user import UserOut
from app.services.email_service import send_password_reset_email
from app.services.usage_service import log_action

router = APIRouter(prefix="/auth", tags=["auth"], dependencies=[Depends(rate_limit_anonymous)])


def _is_expired(expires_at: datetime) -> bool:
    # SQLite (testes) devolve datetimes naive; assume UTC nesses casos
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    return expires_at < datetime.now(timezone.utc)


async def _issue_tokens(db, user: User) -> TokenPair:
    settings = get_settings()
    access = create_access_token(user.id, role=user.role.value)
    refresh = create_refresh_token(user.id)
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_token(refresh),
            expires_at=datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days),
        )
    )
    await db.commit()
    return TokenPair(access_token=access, refresh_token=refresh)


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, db: DbSession, request: Request):
    existing = await db.execute(select(User).where(User.email == payload.email.lower()))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email já registado")
    user = User(
        email=payload.email.lower(),
        hashed_password=hash_password(payload.password),
        full_name=payload.full_name,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    await log_action(db, "auth.register", user.id, request=request)
    return user


@router.post("/login", response_model=TokenPair)
async def login(payload: LoginRequest, db: DbSession, request: Request):
    result = await db.execute(select(User).where(User.email == payload.email.lower()))
    user = result.scalar_one_or_none()
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Email ou senha incorretos")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Conta desativada")
    await log_action(db, "auth.login", user.id, request=request)
    return await _issue_tokens(db, user)


@router.post("/refresh", response_model=TokenPair)
async def refresh_tokens(payload: RefreshRequest, db: DbSession):
    try:
        token_payload = decode_token(payload.refresh_token, REFRESH_TOKEN)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token inválido")

    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token_hash == hash_token(payload.refresh_token))
    )
    stored = result.scalar_one_or_none()
    if stored is None or stored.revoked or _is_expired(stored.expires_at):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token inválido ou revogado")

    user = await db.get(User, token_payload["sub"])
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Utilizador inválido")

    # Rotação: revoga o token usado e emite um novo par
    stored.revoked = True
    return await _issue_tokens(db, user)


@router.post("/logout", response_model=MessageResponse)
async def logout(payload: RefreshRequest, db: DbSession):
    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token_hash == hash_token(payload.refresh_token))
    )
    stored = result.scalar_one_or_none()
    if stored:
        stored.revoked = True
        await db.commit()
    return MessageResponse(message="Sessão terminada")


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(payload: ForgotPasswordRequest, db: DbSession):
    result = await db.execute(select(User).where(User.email == payload.email.lower()))
    user = result.scalar_one_or_none()
    if user:
        token = generate_password_reset_token()
        db.add(
            PasswordResetToken(
                user_id=user.id,
                token_hash=hash_token(token),
                expires_at=datetime.now(timezone.utc) + timedelta(minutes=30),
            )
        )
        await db.commit()
        await send_password_reset_email(user.email, token)
    # Resposta idêntica quer o email exista ou não (evita enumeração de contas)
    return MessageResponse(message="Se o email existir, receberá instruções de recuperação")


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(payload: ResetPasswordRequest, db: DbSession):
    result = await db.execute(
        select(PasswordResetToken).where(PasswordResetToken.token_hash == hash_token(payload.token))
    )
    reset = result.scalar_one_or_none()
    if reset is None or reset.used or _is_expired(reset.expires_at):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Token inválido ou expirado")

    user = await db.get(User, reset.user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Token inválido")

    user.hashed_password = hash_password(payload.new_password)
    reset.used = True
    await db.commit()
    return MessageResponse(message="Senha alterada com sucesso")
