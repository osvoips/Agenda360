from collections.abc import AsyncIterator
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import get_settings

settings = get_settings()

engine = create_async_engine(settings.database_url, pool_pre_ping=True)
async_session_factory = async_sessionmaker(engine, expire_on_commit=False)


async def tenant_db_session(tenant_id: UUID) -> AsyncIterator[AsyncSession]:
    """Opens a transaction scoped to a tenant.

    `set_config(..., true)` is the parameterized equivalent of `SET LOCAL`
    (SET does not accept bind parameters), and applies only for the
    lifetime of this transaction — required for the RLS policies in
    database/schema.sql to isolate tenants.
    """
    async with async_session_factory() as session, session.begin():
        await session.execute(
            text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
            {"tenant_id": str(tenant_id)},
        )
        yield session


