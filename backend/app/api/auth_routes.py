from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_public_db
from app.core.security import create_access_token, verify_password
from app.core.tenant import resolve_tenant_id
from app.models.staff_user import StaffUser
from app.schemas.auth import LoginRequest, TokenResponse

router = APIRouter(prefix="/v1/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
async def login(
    payload: LoginRequest,
    tenant_id: UUID = Depends(resolve_tenant_id),
    db: AsyncSession = Depends(get_public_db),
) -> TokenResponse:
    staff = (
        await db.execute(
            select(StaffUser).where(StaffUser.email == payload.email, StaffUser.is_active.is_(True))
        )
    ).scalar_one_or_none()

    if staff is None or not verify_password(payload.password, staff.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "E-mail ou senha inválidos")

    token = create_access_token(staff_user_id=staff.id, tenant_id=tenant_id, role=staff.role)
    return TokenResponse(access_token=token, role=staff.role)
