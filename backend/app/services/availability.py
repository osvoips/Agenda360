from datetime import date, datetime, timedelta, timezone
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.appointment import Appointment
from app.models.blocked_slot import BlockedSlot
from app.models.business_hours import BusinessHours
from app.models.professional_service import ProfessionalService
from app.models.service import Service

SLOT_GRANULARITY = timedelta(minutes=15)

# MVP tem um único tenant, no Rio de Janeiro. Quando existirem tenants em
# outros fusos, isso precisa virar uma coluna em `tenants` (ver
# docs/DATABASE.md §6 — não incluído nesta versão).
TENANT_TIMEZONE = ZoneInfo("America/Sao_Paulo")


def _to_schema_weekday(python_weekday: int) -> int:
    """Python: segunda=0..domingo=6. Schema (database/schema.sql): domingo=0..sábado=6."""
    return (python_weekday + 1) % 7


async def get_available_slots(
    session: AsyncSession,
    *,
    professional_id: UUID,
    service_id: UUID,
    target_date: date,
) -> list[datetime]:
    service = await session.get(Service, service_id)
    if service is None or not service.is_active:
        return []

    offers_service = await session.get(ProfessionalService, {"professional_id": professional_id, "service_id": service_id})
    if offers_service is None:
        return []

    hours = await session.scalar(
        select(BusinessHours).where(BusinessHours.weekday == _to_schema_weekday(target_date.weekday()))
    )
    if hours is None or hours.is_closed or hours.opens_at is None or hours.closes_at is None:
        return []

    duration = timedelta(minutes=service.duration_minutes)
    day_start = datetime.combine(target_date, hours.opens_at, tzinfo=TENANT_TIMEZONE)
    day_end = datetime.combine(target_date, hours.closes_at, tzinfo=TENANT_TIMEZONE)

    busy_intervals = await _get_busy_intervals(session, professional_id, day_start, day_end)
    now = datetime.now(timezone.utc)

    slots: list[datetime] = []
    candidate = day_start
    while candidate + duration <= day_end:
        if candidate >= now and not _overlaps(candidate, candidate + duration, busy_intervals):
            slots.append(candidate)
        candidate += SLOT_GRANULARITY
    return slots


async def _get_busy_intervals(
    session: AsyncSession, professional_id: UUID, day_start: datetime, day_end: datetime
) -> list[tuple[datetime, datetime]]:
    appt_rows = await session.execute(
        select(Appointment.starts_at, Appointment.ends_at).where(
            Appointment.professional_id == professional_id,
            Appointment.status != "cancelled",
            Appointment.starts_at < day_end,
            Appointment.ends_at > day_start,
        )
    )
    block_rows = await session.execute(
        select(BlockedSlot.starts_at, BlockedSlot.ends_at).where(
            BlockedSlot.professional_id == professional_id,
            BlockedSlot.starts_at < day_end,
            BlockedSlot.ends_at > day_start,
        )
    )
    return [(row.starts_at, row.ends_at) for row in appt_rows] + [(row.starts_at, row.ends_at) for row in block_rows]


def _overlaps(start: datetime, end: datetime, intervals: list[tuple[datetime, datetime]]) -> bool:
    return any(start < busy_end and end > busy_start for busy_start, busy_end in intervals)
