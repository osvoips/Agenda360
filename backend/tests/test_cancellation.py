from datetime import datetime, timedelta, timezone

from app.models.appointment import Appointment
from app.models.client import Client


async def _book_slot(client, seeded_tenant, *, days_ahead: int, phone: str) -> dict:
    target_date = (datetime.now(timezone.utc) + timedelta(days=days_ahead)).date()
    availability = await client.get(
        "/v1/availability",
        params={
            "professional_id": str(seeded_tenant["professional_id"]),
            "service_id": str(seeded_tenant["service_id"]),
            "date": target_date.isoformat(),
        },
    )
    slot = availability.json()["slots"][0]

    response = await client.post(
        "/v1/appointments",
        json={
            "client_name": "Bruno Alves",
            "client_phone": phone,
            "service_id": str(seeded_tenant["service_id"]),
            "professional_id": str(seeded_tenant["professional_id"]),
            "starts_at": slot,
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


async def test_cancel_with_enough_notice_succeeds(client, seeded_tenant):
    appointment = await _book_slot(client, seeded_tenant, days_ahead=2, phone="21977776666")

    response = await client.post(
        f"/v1/appointments/{appointment['id']}/cancel", json={"phone": "21977776666"}
    )
    assert response.status_code == 200, response.text
    assert response.json()["status"] == "cancelled"


async def test_cancel_with_wrong_phone_is_rejected(client, seeded_tenant):
    appointment = await _book_slot(client, seeded_tenant, days_ahead=2, phone="21977776666")

    response = await client.post(
        f"/v1/appointments/{appointment['id']}/cancel", json={"phone": "21900000000"}
    )
    assert response.status_code == 403


async def test_cancel_within_min_notice_window_is_rejected(client, seeded_tenant, db_session_factory):
    # Cria o agendamento direto no banco (fora do fluxo público) para poder
    # controlar precisamente `starts_at`: daqui a 30 minutos, dentro da
    # janela mínima padrão de 120 minutos (tenants.min_cancel_notice_minutes).
    async with db_session_factory() as session:
        client_row = Client(tenant_id=seeded_tenant["tenant_id"], name="Igor Ramos", phone="21955554444")
        session.add(client_row)
        await session.flush()

        starts_at = datetime.now(timezone.utc) + timedelta(minutes=30)
        appointment = Appointment(
            tenant_id=seeded_tenant["tenant_id"],
            client_id=client_row.id,
            professional_id=seeded_tenant["professional_id"],
            service_id=seeded_tenant["service_id"],
            starts_at=starts_at,
            ends_at=starts_at + timedelta(minutes=45),
            status="scheduled",
        )
        session.add(appointment)
        await session.commit()
        appointment_id = appointment.id

    response = await client.post(
        f"/v1/appointments/{appointment_id}/cancel", json={"phone": "21955554444"}
    )
    assert response.status_code == 409
