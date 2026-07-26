"""Popula o tenant piloto (Carioca Barbearia) para desenvolvimento local.

Roda com a role dona do schema (ADMIN_DATABASE_URL), então ignora RLS por
padrão do Postgres — comportamento esperado para um script de seed.

Uso: python -m app.seed
"""

import asyncio
from datetime import time

from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.core.security import hash_password
from app.models import BusinessHours, Professional, ProfessionalService, Service, StaffUser, Tenant, TenantBranding

TENANT_SLUG = "carioca-barbearia"
ADMIN_EMAIL = "admin@cariocabarbearia.com.br"
ADMIN_PASSWORD = "trocar-esta-senha"

# weekday: 0=domingo .. 6=sábado (convenção de database/schema.sql)
BUSINESS_HOURS = [
    (1, time(9, 0), time(19, 0)),  # segunda
    (2, time(9, 0), time(19, 0)),  # terça
    (3, time(9, 0), time(19, 0)),  # quarta
    (4, time(9, 0), time(19, 0)),  # quinta
    (5, time(9, 0), time(20, 0)),  # sexta
    (6, time(8, 0), time(17, 0)),  # sábado
]


async def seed() -> None:
    settings = get_settings()
    engine = create_async_engine(settings.admin_database_url)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)

    async with session_factory() as session:
        existing = await session.execute(select(Tenant).where(Tenant.slug == TENANT_SLUG))
        if existing.scalar_one_or_none() is not None:
            print(f"Tenant '{TENANT_SLUG}' já existe — nada a fazer.")
            await engine.dispose()
            return

        tenant = Tenant(slug=TENANT_SLUG, name="Carioca Barbearia", segment="barbershop")
        session.add(tenant)
        await session.flush()

        session.add(
            TenantBranding(
                tenant_id=tenant.id,
                display_name="Carioca Barbearia",
                primary_color="#E30613",
                secondary_color="#131217",
            )
        )

        anderson = Professional(tenant_id=tenant.id, name="Anderson")
        session.add(anderson)
        await session.flush()

        # Pigmentação/Sobrancelha ficam de fora: duração ainda "a definir"
        # em REQUIREMENTS.md, e duration_minutes é obrigatório no schema.
        services = [
            Service(tenant_id=tenant.id, name="Corte Masculino", duration_minutes=45),
            Service(tenant_id=tenant.id, name="Barba", duration_minutes=30),
            Service(tenant_id=tenant.id, name="Corte + Barba", duration_minutes=70),
        ]
        session.add_all(services)
        await session.flush()

        for service in services:
            session.add(
                ProfessionalService(tenant_id=tenant.id, professional_id=anderson.id, service_id=service.id)
            )

        for weekday, opens_at, closes_at in BUSINESS_HOURS:
            session.add(
                BusinessHours(
                    tenant_id=tenant.id, weekday=weekday, opens_at=opens_at, closes_at=closes_at, is_closed=False
                )
            )
        session.add(BusinessHours(tenant_id=tenant.id, weekday=0, is_closed=True))  # domingo

        session.add(
            StaffUser(
                tenant_id=tenant.id,
                name="Administrador",
                email=ADMIN_EMAIL,
                password_hash=hash_password(ADMIN_PASSWORD),
                role="admin",
            )
        )

        await session.commit()
        print(f"Seed concluído. Tenant: {tenant.slug} (id={tenant.id})")
        print(f"Login admin: {ADMIN_EMAIL} / {ADMIN_PASSWORD}  (troque em produção)")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed())
