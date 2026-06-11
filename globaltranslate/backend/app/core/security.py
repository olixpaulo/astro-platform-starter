"""JWT, hashing de senhas e criptografia de dados sensíveis."""
import base64
import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

from cryptography.fernet import Fernet
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

ACCESS_TOKEN = "access"
REFRESH_TOKEN = "refresh"


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def _create_token(subject: str, token_type: str, expires_delta: timedelta, extra: dict[str, Any] | None = None) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": subject,
        "type": token_type,
        "iat": now,
        "exp": now + expires_delta,
        "jti": secrets.token_hex(16),
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)


def create_access_token(user_id: str, role: str = "user") -> str:
    settings = get_settings()
    return _create_token(user_id, ACCESS_TOKEN, timedelta(minutes=settings.access_token_expire_minutes), {"role": role})


def create_refresh_token(user_id: str) -> str:
    settings = get_settings()
    return _create_token(user_id, REFRESH_TOKEN, timedelta(days=settings.refresh_token_expire_days))


def decode_token(token: str, expected_type: str) -> dict[str, Any]:
    """Decodifica e valida um JWT. Lança JWTError se inválido/expirado."""
    settings = get_settings()
    payload = jwt.decode(token, settings.secret_key, algorithms=[settings.jwt_algorithm])
    if payload.get("type") != expected_type:
        raise JWTError("Tipo de token inválido")
    return payload


def generate_password_reset_token() -> str:
    return secrets.token_urlsafe(32)


def hash_token(token: str) -> str:
    """Hash de tokens opacos (refresh/reset) antes de persistir — nunca em claro na BD."""
    return hashlib.sha256(token.encode()).hexdigest()


def _fernet() -> Fernet:
    settings = get_settings()
    if settings.encryption_key:
        key = settings.encryption_key.encode()
    else:
        # Deriva uma chave estável a partir da SECRET_KEY (apenas para desenvolvimento)
        key = base64.urlsafe_b64encode(hashlib.sha256(get_settings().secret_key.encode()).digest())
    return Fernet(key)


def encrypt_sensitive(value: str) -> str:
    return _fernet().encrypt(value.encode()).decode()


def decrypt_sensitive(value: str) -> str:
    return _fernet().decrypt(value.encode()).decode()
