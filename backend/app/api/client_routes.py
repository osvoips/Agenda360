from datetime import date as date_type
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_public_db
from app.core.tenant import resolve_tenant_id
from app.models.appointment import Appointment
from app.models.client import Client
from app.models.professional import Professional
from app.models.professional_service import ProfessionalService
from app.models.service import Service
from app.models.tenant import Tenant, TenantBranding
from app.schemas.appointment import AppointmentCancelRequest, AppointmentCreate, AppointmentOut
from app.schemas.professional import ProfessionalOut
from app.schemas.service import ServiceOut
from app.schemas.tenant import TenantOut
from app.services.availability import get_available_slots

router = APIRouter(prefix="/v1", tags=["cliente"])


@router.get("/tenant", response_model=TenantOut)
async def get_tenant(
    tenant_id: UUID = Depends(resolve_tenant_id),
    db: AsyncSession = Depends(get_public_db),
) -> TenantOut:
    tenant = await db.get(Tenant, tenant_id)
    branding = await db.get(TenantBranding, tenant_id)
    return TenantOut(
        slug=tenant.slug,
        display_name=branding.display_name if branding else tenant.name,
        logo_url=branding.logo_url if branding else None,
        icon_url=branding.icon_url if branding else None,
        primary_color=branding.primary_color if branding else None,
        secondary_color=branding.secondary_color if branding else None,
        min_cancel_notice_minutes=tenant.min_cancel_notice_minutes,
    )


@router.get("/services", response_model=list[ServiceOut])
async def list_services(db: AsyncSession = Depends(get_public_db)) -> list[Service]:
    result = await db.execute(select(Service).where(Service.is_active.is_(True)).order_by(Service.name))
    return list(result.scalars().all())


@router.get("/professionals", response_model=list[ProfessionalOut])
async def list_professionals(
    service_id: UUID = Query(...),
    db: AsyncSession = Depends(get_public_db),
) -> list[Professional]:
    result = await db.execute(
        select(Professional)
        .join(ProfessionalService, ProfessionalService.professional_id == Professional.id)
        .where(ProfessionalService.service_id == service_id, Professional.is_active.is_(True))
        .order_by(Professional.name)
    )
    return list(result.scalars().all())


@router.get("/availability")
async def get_availability(
    professional_id: UUID = Query(...),
    service_id: UUID = Query(...),
    date: date_type = Query(...),
    db: AsyncSession = Depends(get_public_db),
) -> dict:
    slots = await get_available_slots(
        db, professional_id=professional_id, service_id=service_id, target_date=date
    )
    return {"date": date, "slots": slots}


@router.post("/appointments", response_model=AppointmentOut, status_code=status.HTTP_201_CREATED)
async def create_appointment(
    payload: AppointmentCreate,
    tenant_id: UUID = Depends(resolve_tenant_id),
    db: AsyncSession = Depends(get_public_db),
) -> Appointment:
    service = await db.get(Service, payload.service_id)
    if service is None or not service.is_active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Serviço não encontrado")

    professional = await db.get(Professional, payload.professional_id)
    if professional is None or not professional.is_active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Profissional não encontrado")

    if payload.starts_at <= datetime.now(timezone.utc):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Não é possível agendar no passado")

    available_slots = await get_available_slots(
        db,
        professional_id=payload.professional_id,
        service_id=payload.service_id,
        target_date=payload.starts_at.date(),
    )
    if payload.starts_at not in available_slots:
        raise HTTPException(status.HTTP_409_CONFLICT, "Horário indisponível")

    client = (
        await db.execute(select(Client).where(Client.phone == payload.client_phone))
    ).scalar_one_or_none()
    if client is None:
        client = Client(tenant_id=tenant_id, name=payload.client_name, phone=payload.client_phone)
        db.add(client)
        await db.flush()
    else:
        client.name = payload.client_name

    appointment = Appointment(
        tenant_id=tenant_id,
        client_id=client.id,
        professional_id=payload.professional_id,
        service_id=payload.service_id,
        starts_at=payload.starts_at,
        ends_at=payload.starts_at + timedelta(minutes=service.duration_minutes),
        status="scheduled",
    )
    db.add(appointment)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, "Horário acabou de ser ocupado, escolha outro") from exc

    return appointment


@router.post("/appointments/{appointment_id}/cancel", response_model=AppointmentOut)
async def cancel_appointment(
    appointment_id: UUID,
    payload: AppointmentCancelRequest,
    tenant_id: UUID = Depends(resolve_tenant_id),
    db: AsyncSession = Depends(get_public_db),
) -> Appointment:
    appointment = await db.get(Appointment, appointment_id)
    if appointment is None or appointment.status == "cancelled":
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Agendamento não encontrado")

    client = await db.get(Client, appointment.client_id)
    if client is None or client.phone != payload.phone:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Telefone não confere com o agendamento")

    tenant = await db.get(Tenant, tenant_id)
    min_notice = timedelta(minutes=tenant.min_cancel_notice_minutes)
    if datetime.now(timezone.utc) > appointment.starts_at - min_notice:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Cancelamento permitido só até {tenant.min_cancel_notice_minutes} minutos antes do horário",
        )

    appointment.status = "cancelled"
    appointment.cancelled_at = datetime.now(timezone.utc)
    await db.flush()
    return appointment
