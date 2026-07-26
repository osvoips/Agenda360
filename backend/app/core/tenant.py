from uuid import UUID

from fastapi import Header, HTTPException, status
from sqlalchemy import select

from app.core.db import async_session_factory
from app.models.tenant import Tenant


async def resolve_tenant_id(x_tenant_slug: str = Header(..., alias="X-Tenant-Slug")) -> UUID:
    """Resolves a tenant slug to its id.

    Relies on the public `tenant_read` RLS policy (database/schema.sql) —
    at this point `app.tenant_id` isn't set yet, this call is what
    determines it for the rest of the request.
    """
    async with async_session_factory() as session, session.begin():
        result = await session.execute(
            select(Tenant.id).where(Tenant.slug == x_tenant_slug, Tenant.is_active.is_(True))
        )
        tenant_id = result.scalar_one_or_none()

    if tenant_id is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tenant não encontrado")
    return tenant_id
