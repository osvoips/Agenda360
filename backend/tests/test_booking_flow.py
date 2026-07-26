from datetime import datetime, timedelta, timezone


async def test_list_services(client, seeded_tenant):
    response = await client.get("/v1/services")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["name"] == "Corte Masculino"


async def test_list_professionals_for_service(client, seeded_tenant):
    response = await client.get("/v1/professionals", params={"service_id": str(seeded_tenant["service_id"])})
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["name"] == "Anderson"


async def test_availability_and_booking_flow(client, seeded_tenant):
    target_date = (datetime.now(timezone.utc) + timedelta(days=1)).date()

    availability = await client.get(
        "/v1/availability",
        params={
            "professional_id": str(seeded_tenant["professional_id"]),
            "service_id": str(seeded_tenant["service_id"]),
            "date": target_date.isoformat(),
        },
    )
    assert availability.status_code == 200
    slots = availability.json()["slots"]
    assert len(slots) > 0

    chosen_slot = slots[0]

    create_response = await client.post(
        "/v1/appointments",
        json={
            "client_name": "Rafael Souza",
            "client_phone": "21988884321",
            "service_id": str(seeded_tenant["service_id"]),
            "professional_id": str(seeded_tenant["professional_id"]),
            "starts_at": chosen_slot,
        },
    )
    assert create_response.status_code == 201, create_response.text
    appointment = create_response.json()
    assert appointment["status"] == "scheduled"

    # o horário escolhido não deve mais aparecer como disponível
    availability_after = await client.get(
        "/v1/availability",
        params={
            "professional_id": str(seeded_tenant["professional_id"]),
            "service_id": str(seeded_tenant["service_id"]),
            "date": target_date.isoformat(),
        },
    )
    assert chosen_slot not in availability_after.json()["slots"]

    # tentar agendar o mesmo horário de novo deve falhar (RF-CLI-04 / anti-overlap)
    conflict_response = await client.post(
        "/v1/appointments",
        json={
            "client_name": "Outro Cliente",
            "client_phone": "21999990000",
            "service_id": str(seeded_tenant["service_id"]),
            "professional_id": str(seeded_tenant["professional_id"]),
            "starts_at": chosen_slot,
        },
    )
    assert conflict_response.status_code == 409


async def test_booking_in_the_past_is_rejected(client, seeded_tenant):
    past = datetime.now(timezone.utc) - timedelta(hours=1)
    response = await client.post(
        "/v1/appointments",
        json={
            "client_name": "Rafael Souza",
            "client_phone": "21988884321",
            "service_id": str(seeded_tenant["service_id"]),
            "professional_id": str(seeded_tenant["professional_id"]),
            "starts_at": past.isoformat(),
        },
    )
    assert response.status_code == 422
