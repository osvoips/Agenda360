from collections.abc import AsyncIterator
from uuid import UUID

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import tenant_db_session
from app.core.security import decode_access_token
from app.core.tenant import resolve_tenant_id
from app.models.staff_user import StaffUser


async def get_public_db(tenant_id: UUID = Depends(resolve_tenant_id)) -> AsyncIterator[AsyncSession]:
    async for session in tenant_db_session(tenant_id):
        yield session


class CurrentStaff:
    def __init__(self, staff_id: UUID, tenant_id: UUID, role: str):
        self.staff_id = staff_id
        self.tenant_id = tenant_id
        self.role = role


async def get_current_staff(authorization: str | None = Header(default=None)) -> CurrentStaff:
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Não autenticado")

    token = authorization.removeprefix("Bearer ").strip()
    payload = decode_access_token(token)
    if payload is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido ou expirado")

    # O JWT por si só não prova que o tenant/usuário ainda existem neste
    # banco: um token assinado por outro ambiente com o mesmo JWT_SECRET
    # (ex.: o valor padrão de .env.example) passaria na verificação de
    # assinatura mas apontaria para um tenant_id inexistente aqui, e as
    # queries com RLS voltariam listas vazias em silêncio em vez de 401.
    staff_user: StaffUser | None = None
    async for session in tenant_db_session(payload.tenant_id):
        staff_user = await session.get(StaffUser, payload.staff_user_id)
    if staff_user is None or not staff_user.is_active or staff_user.role != payload.role:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido ou expirado")

    return CurrentStaff(staff_id=payload.staff_user_id, tenant_id=payload.tenant_id, role=payload.role)


async def get_staff_db(staff: CurrentStaff = Depends(get_current_staff)) -> AsyncIterator[AsyncSession]:
    async for session in tenant_db_session(staff.tenant_id):
        yield session


def require_admin(staff: CurrentStaff = Depends(get_current_staff)) -> CurrentStaff:
    if staff.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso restrito ao administrador")
    return staff
