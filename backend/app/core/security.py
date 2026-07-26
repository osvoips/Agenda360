from datetime import datetime, timedelta, timezone
from uuid import UUID

import bcrypt
from jose import JWTError, jwt

from app.core.config import get_settings

settings = get_settings()

# passlib (CryptContext) é incompatível com bcrypt>=4.1 (removeu o atributo
# `__about__` que passlib usa para detectar a versão, e passou a levantar
# ValueError em vez de truncar silenciosamente senhas > 72 bytes) — passlib
# está sem manutenção desde 2020. Usamos o pacote bcrypt direto.
_BCRYPT_MAX_BYTES = 72


def hash_password(password: str) -> str:
    truncated = password.encode("utf-8")[:_BCRYPT_MAX_BYTES]
    return bcrypt.hashpw(truncated, bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    truncated = password.encode("utf-8")[:_BCRYPT_MAX_BYTES]
    return bcrypt.checkpw(truncated, password_hash.encode("utf-8"))


def create_access_token(*, staff_user_id: UUID, tenant_id: UUID, role: str) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes)
    payload = {
        "sub": str(staff_user_id),
        "tenant_id": str(tenant_id),
        "role": role,
        "exp": expires_at,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


class TokenPayload:
    def __init__(self, staff_user_id: UUID, tenant_id: UUID, role: str):
        self.staff_user_id = staff_user_id
        self.tenant_id = tenant_id
        self.role = role


def decode_access_token(token: str) -> TokenPayload | None:
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except JWTError:
        return None
    try:
        return TokenPayload(
            staff_user_id=UUID(payload["sub"]),
            tenant_id=UUID(payload["tenant_id"]),
            role=payload["role"],
        )
    except (KeyError, ValueError):
        return None
