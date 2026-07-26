from datetime import date, datetime, time, timedelta

from sqlalchemy import select
from sqlalchemy.engine import Row
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.appointment import Appointment
from app.models.client import Client
from app.schemas.appointment import AgendaAppointmentOut
from app.services.availability import TENANT_TIMEZONE


def day_range(target_date: date) -> tuple[datetime, datetime]:
    start = datetime.combine(target_date, time.min, tzinfo=TENANT_TIMEZONE)
    return start, start + timedelta(days=1)


def week_range(start_date: date) -> tuple[datetime, datetime]:
    start = datetime.combine(start_date, time.min, tzinfo=TENANT_TIMEZONE)
    return start, start + timedelta(days=7)


async def get_agenda_rows(session: AsyncSession, *, start: datetime, end: datetime) -> list[Row]:
    result = await session.execute(
        select(Appointment, Client.name, Client.phone)
        .join(Client, Client.id == Appointment.client_id)
        .where(Appointment.starts_at >= start, Appointment.starts_at < end)
        .order_by(Appointment.starts_at)
    )
    return list(result)


def serialize_agenda_rows(rows: list[Row]) -> list[AgendaAppointmentOut]:
    return [
        AgendaAppointmentOut(
            id=appt.id,
            professional_id=appt.professional_id,
            service_id=appt.service_id,
            client_name=name,
            client_phone=phone,
            starts_at=appt.starts_at,
            ends_at=appt.ends_at,
            status=appt.status,
        )
        for appt, name, phone in rows
    ]
