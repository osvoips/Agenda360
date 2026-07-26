"""RNF-01: nenhum dado de um tenant pode ser acessível por outro."""

import uuid

from httpx import ASGITransport, AsyncClient

from app.main import app
from app.models import Professional, Service, Tenant, TenantBranding


async def _create_second_tenant(db_session_factory) -> dict:
    async with db_session_factory() as session:
        slug = f"test-tenant-{uuid.uuid4().hex[:8]}"
        tenant = Tenant(slug=slug, name="Other Barbershop")
        session.add(tenant)
        await session.flush()

        session.add(TenantBranding(tenant_id=tenant.id, display_name="Other Barbershop"))

        professional = Professional(tenant_id=tenant.id, name="Carlos")
        session.add(professional)

        service = Service(tenant_id=tenant.id, name="Corte Simples", duration_minutes=30)
        session.add(service)

        await session.commit()
        return {"slug": slug, "service_name": service.name}


async def test_service_lists_are_isolated_between_tenants(client, seeded_tenant, db_session_factory):
    other_tenant = await _create_second_tenant(db_session_factory)

    # tenant A não vê o serviço do tenant B
    response_a = await client.get("/v1/services")
    names_a = {item["name"] for item in response_a.json()}
    assert "Corte Simples" not in names_a
    assert "Corte Masculino" in names_a

    # tenant B não vê o serviço do tenant A
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test", headers={"X-Tenant-Slug": other_tenant["slug"]}
    ) as client_b:
        response_b = await client_b.get("/v1/services")
        names_b = {item["name"] for item in response_b.json()}
        assert "Corte Masculino" not in names_b
        assert "Corte Simples" in names_b
