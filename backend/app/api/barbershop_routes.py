from datetime import date as date_type
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentStaff, get_current_staff, get_staff_db
from app.models.appointment import Appointment
from app.models.blocked_slot import BlockedSlot
from app.models.business_hours import BusinessHours
from app.models.professional import Professional
from app.schemas.appointment import AgendaAppointmentOut, AppointmentOut, AppointmentStaffCancelRequest
from app.schemas.blocked_slot import BlockedSlotCreate, BlockedSlotOut
from app.schemas.business_hours import BusinessHoursItem, BusinessHoursUpdate
from app.schemas.professional import ProfessionalOut
from app.services.agenda import day_range, get_agenda_rows, serialize_agenda_rows, week_range

router = APIRouter(prefix="/v1/barbershop", tags=["barbearia"])
hours_router = APIRouter(prefix="/v1", tags=["barbearia", "administrador"])


# Suporte a RF-BAR-05 (bloquear horário): staff precisa saber os IDs dos
# profissionais para escolher quem está sendo bloqueado, mas não tem
# acesso a /v1/admin/professionals (role=admin) nem faz sentido usar o
# endpoint público /v1/professionals (exige service_id, que não existe
# no contexto de um bloqueio).
@router.get("/professionals", response_model=list[ProfessionalOut])
async def list_professionals_for_staff(
    staff: CurrentStaff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_staff_db),
) -> list[Professional]:
    result = await db.execute(
        select(Professional).where(Professional.is_active.is_(True)).order_by(Professional.name)
    )
    return list(result.scalars().all())


@router.get("/agenda/day", response_model=list[AgendaAppointmentOut])
async def get_day_agenda(
    date: date_type = Query(...),
    staff: CurrentStaff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_staff_db),
) -> list[AgendaAppointmentOut]:
    start, end = day_range(date)
    rows = await get_agenda_rows(db, start=start, end=end)
    return serialize_agenda_rows(rows)


@router.get("/agenda/week", response_model=list[AgendaAppointmentOut])
async def get_week_agenda(
    start_date: date_type = Query(...),
    staff: CurrentStaff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_staff_db),
) -> list[AgendaAppointmentOut]:
    start, end = week_range(start_date)
    rows = await get_agenda_rows(db, start=start, end=end)
    return serialize_agenda_rows(rows)


@router.post("/appointments/{appointment_id}/confirm", response_model=AppointmentOut)
async def confirm_appointment(
    appointment_id: UUID,
    staff: CurrentStaff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_staff_db),
) -> Appointment:
    appointment = await db.get(Appointment, appointment_id)
    if appointment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Agendamento não encontrado")
    if appointment.status == "cancelled":
        raise HTTPException(status.HTTP_409_CONFLICT, "Agendamento já foi cancelado")

    appointment.status = "confirmed"
    await db.flush()
    return appointment


@router.post("/appointments/{appointment_id}/cancel", response_model=AppointmentOut)
async def staff_cancel_appointment(
    appointment_id: UUID,
    payload: AppointmentStaffCancelRequest,
    staff: CurrentStaff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_staff_db),
) -> Appointment:
    appointment = await db.get(Appointment, appointment_id)
    if appointment is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Agendamento não encontrado")

    appointment.status = "cancelled"
    appointment.cancelled_at = datetime.now(timezone.utc)
    appointment.cancel_reason = payload.reason
    await db.flush()
    return appointment


@router.post("/blocked-slots", response_model=BlockedSlotOut, status_code=status.HTTP_201_CREATED)
async def create_blocked_slot(
    payload: BlockedSlotCreate,
    staff: CurrentStaff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_staff_db),
) -> BlockedSlot:
    blocked = BlockedSlot(
        tenant_id=staff.tenant_id,
        professional_id=payload.professional_id,
        starts_at=payload.starts_at,
        ends_at=payload.ends_at,
        reason=payload.reason,
    )
    db.add(blocked)
    await db.flush()
    return blocked


@router.delete("/blocked-slots/{blocked_slot_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_blocked_slot(
    blocked_slot_id: UUID,
    staff: CurrentStaff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_staff_db),
) -> None:
    blocked = await db.get(BlockedSlot, blocked_slot_id)
    if blocked is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bloqueio não encontrado")
    await db.delete(blocked)


# RF-BAR-06 e RF-ADM-03 descrevem a mesma funcionalidade sob dois atores —
# um único endpoint, acessível a `staff` e `admin`.
@hours_router.get("/business-hours", response_model=list[BusinessHoursItem])
async def get_business_hours(
    staff: CurrentStaff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_staff_db),
) -> list[BusinessHours]:
    result = await db.execute(select(BusinessHours).order_by(BusinessHours.weekday))
    return list(result.scalars().all())


@hours_router.put("/business-hours", response_model=list[BusinessHoursItem])
async def update_business_hours(
    payload: BusinessHoursUpdate,
    staff: CurrentStaff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_staff_db),
) -> list[BusinessHours]:
    for item in payload.days:
        existing = await db.get(BusinessHours, {"tenant_id": staff.tenant_id, "weekday": item.weekday})
        if existing is None:
            existing = BusinessHours(tenant_id=staff.tenant_id, weekday=item.weekday)
            db.add(existing)
        existing.opens_at = item.opens_at
        existing.closes_at = item.closes_at
        existing.is_closed = item.is_closed

    await db.flush()
    result = await db.execute(select(BusinessHours).order_by(BusinessHours.weekday))
    return list(result.scalars().all())
