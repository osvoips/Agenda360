"""Cobre o suporte de RF-BAR-05 usado pelo app_admin: staff precisa listar
profissionais para escolher quem está sendo bloqueado, sem precisar de
role=admin."""


async def _login(client, seeded_tenant) -> str:
    response = await client.post(
        "/v1/auth/login",
        json={"email": seeded_tenant["admin_email"], "password": seeded_tenant["admin_password"]},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


async def test_staff_can_list_professionals(client, seeded_tenant):
    token = await _login(client, seeded_tenant)

    response = await client.get(
        "/v1/barbershop/professionals",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200, response.text
    names = {item["name"] for item in response.json()}
    assert "Anderson" in names


async def test_barbershop_professionals_requires_auth(client, seeded_tenant):
    response = await client.get("/v1/barbershop/professionals")
    assert response.status_code == 401
