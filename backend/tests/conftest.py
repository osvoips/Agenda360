"""Fixtures dos testes de integração.

Roda contra um Postgres real (não SQLite/mocks): RLS e o EXCLUDE USING gist
de `appointments` só existem no Postgres de verdade. Requer o `db` do
docker/docker-compose.yml no ar — ver README.md do backend.
"""

import os
import uuid
from pathlib import Path


def _with_test_db(url: str) -> str:
    """Troca só o nome do banco por `agenda360_test`, preservando host/porta/
    credenciais — dentro do container da API isso é `db` (rede do
    docker-compose), fora dele costuma ser `localhost`. Fixar `localhost`
    aqui quebraria ao rodar via `docker compose exec api pytest`."""
    base = url.rsplit("/", 1)[0]
    return f"{base}/agenda360_test"


# Precisa ser definido antes de qualquer `from app...` — app.core.db abre o
# engine no import, usando get_settings() (lru_cache). Lemos o que já está
# no ambiente (definido pelo docker-compose ou pelo .env) como base.
os.environ["DATABASE_URL"] = _with_test_db(
    os.environ.get("DATABASE_URL", "postgresql+asyncpg://agenda360_app:agenda360_app@localhost:5432/agenda360")
)
os.environ["ADMIN_DATABASE_URL"] = _with_test_db(
    os.environ.get("ADMIN_DATABASE_URL", "postgresql+asyncpg://agenda360:agenda360@localhost:5432/agenda360")
)

from datetime import time  # noqa: E402

import pytest_asyncio  # noqa: E402
from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy import text  # noqa: E402
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine  # noqa: E402

from app.core.config import get_settings  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.main import app  # noqa: E402
from app.models import BusinessHours, Professional, ProfessionalService, Service, StaffUser, Tenant, TenantBranding  # noqa: E402

BACKEND_DIR = Path(__file__).resolve().parent.parent
TEST_DB_NAME = "agenda360_test"


def _run_migrations() -> None:
    settings = get_settings()
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "alembic"))
    cfg.set_main_option(
        "sqlalchemy.url", settings.admin_database_url.replace("postgresql+asyncpg", "postgresql+psycopg2")
    )
    command.upgrade(cfg, "head")


@pytest_asyncio.fixture(scope="session", autouse=True)
async def _prepare_database():
    settings = get_settings()
    bootstrap_url = settings.admin_database_url.rsplit("/", 1)[0] + "/postgres"
    bootstrap_engine = create_async_engine(bootstrap_url, isolation_level="AUTOCOMMIT")
    async with bootstrap_engine.connect() as conn:
        await conn.execute(text(f'DROP DATABASE IF EXISTS "{TEST_DB_NAME}" WITH (FORCE)'))
        await conn.execute(text(f'CREATE DATABASE "{TEST_DB_NAME}"'))
    await bootstrap_engine.dispose()

    _run_migrations()
    yield


@pytest_asyncio.fixture
async def db_engine(_prepare_database):
    # Escopo de função, não sessão: pytest-asyncio roda cada teste num
    # event loop novo, e conexões asyncpg presas a um engine de sessão
    # quebram ao serem reusadas de um loop diferente ("another operation
    # is in progress" / "attached to a different loop").
    settings = get_settings()
    engine = create_async_engine(settings.admin_database_url)
    yield engine
    await engine.dispose()


@pytest_asyncio.fixture
async def db_session_factory(db_engine):
    return async_sessionmaker(db_engine, expire_on_commit=False)


@pytest_asyncio.fixture
async def seeded_tenant(db_session_factory):
    """Cria um tenant novo (slug único) por teste — evita truncar tabelas."""
    async with db_session_factory() as session:
        slug = f"test-tenant-{uuid.uuid4().hex[:8]}"
        tenant = Tenant(slug=slug, name="Test Barbershop")
        session.add(tenant)
        await session.flush()

        session.add(TenantBranding(tenant_id=tenant.id, display_name="Test Barbershop"))

        professional = Professional(tenant_id=tenant.id, name="Anderson")
        session.add(professional)
        await session.flush()

        service = Service(tenant_id=tenant.id, name="Corte Masculino", duration_minutes=45)
        session.add(service)
        await session.flush()

        session.add(
            ProfessionalService(tenant_id=tenant.id, professional_id=professional.id, service_id=service.id)
        )

        # segunda a sábado 09h-18h, domingo fechado — cobre qualquer dia usado nos testes
        for weekday in range(7):
            is_closed = weekday == 0
            session.add(
                BusinessHours(
                    tenant_id=tenant.id,
                    weekday=weekday,
                    opens_at=None if is_closed else time(9, 0),
                    closes_at=None if is_closed else time(18, 0),
                    is_closed=is_closed,
                )
            )

        admin_password = "secret123"
        session.add(
            StaffUser(
                tenant_id=tenant.id,
                name="Admin",
                email="admin@test.com",
                password_hash=hash_password(admin_password),
                role="admin",
            )
        )

        await session.commit()

        return {
            "tenant_id": tenant.id,
            "slug": slug,
            "professional_id": professional.id,
            "service_id": service.id,
            "admin_email": "admin@test.com",
            "admin_password": admin_password,
        }


@pytest_asyncio.fixture
async def client(seeded_tenant):
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test", headers={"X-Tenant-Slug": seeded_tenant["slug"]}
    ) as ac:
        yield ac
