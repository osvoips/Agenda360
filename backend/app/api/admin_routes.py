from datetime import date as date_type
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentStaff, get_staff_db, require_admin
from app.models.professional import Professional
from app.models.professional_service import ProfessionalService
from app.models.promotion import Promotion
from app.models.service import Service
from app.schemas.appointment import AgendaAppointmentOut
from app.schemas.professional import ProfessionalCreate, ProfessionalOut, ProfessionalUpdate
from app.schemas.promotion import PromotionCreate, PromotionOut, PromotionUpdate
from app.schemas.service import ServiceCreate, ServiceOut, ServiceUpdate
from app.services.agenda import day_range, get_agenda_rows, serialize_agenda_rows

router = APIRouter(prefix="/v1/admin", tags=["administrador"])


# --- Profissionais (RF-ADM-01) -------------------------------------------


@router.get("/professionals", response_model=list[ProfessionalOut])
async def list_professionals(
    admin: CurrentStaff = Depends(require_admin),
    db: AsyncSession = Depends(get_staff_db),
) -> list[Professional]:
    result = await db.execute(select(Professional).order_by(Professional.name))
    return list(result.scalars().all())


@router.post("/professionals", response_model=ProfessionalOut, status_code=status.HTTP_201_CREATED)
async def create_professional(
    payload: ProfessionalCreate,
    admin: CurrentStaff = Depends(require_admin),
    db: AsyncSession = Depends(get_staff_db),
) -> Professional:
    professional = Professional(tenant_id=admin.tenant_id, name=payload.name, phone=payload.phone)
    db.add(professional)
    await db.flush()

    for service_id in payload.service_ids:
        db.add(ProfessionalService(tenant_id=admin.tenant_id, professional_id=professional.id, service_id=service_id))
    await db.flush()
    return professional


@router.put("/professionals/{professional_id}", response_model=ProfessionalOut)
async def update_professional(
    professional_id: UUID,
    payload: ProfessionalUpdate,
    admin: CurrentStaff = Depends(require_admin),
    db: AsyncSession = Depends(get_staff_db),
) -> Professional:
    professional = await db.get(Professional, professional_id)
    if professional is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Profissional não encontrado")

    if payload.name is not None:
        professional.name = payload.name
    if payload.phone is not None:
        professional.phone = payload.phone
    if payload.is_active is not None:
        professional.is_active = payload.is_active
    if payload.service_ids is not None:
        await db.execute(delete(ProfessionalService).where(ProfessionalService.professional_id == professional_id))
        for service_id in payload.service_ids:
            db.add(
                ProfessionalService(
                    tenant_id=admin.tenant_id, professional_id=professional_id, service_id=service_id
                )
            )

    await db.flush()
    return professional


# --- Serviços (RF-ADM-02) -------------------------------------------------


@router.get("/services", response_model=list[ServiceOut])
async def list_services(
    admin: CurrentStaff = Depends(require_admin),
    db: AsyncSession = Depends(get_staff_db),
) -> list[Service]:
    result = await db.execute(select(Service).order_by(Service.name))
    return list(result.scalars().all())


@router.post("/services", response_model=ServiceOut, status_code=status.HTTP_201_CREATED)
async def create_service(
    payload: ServiceCreate,
    admin: CurrentStaff = Depends(require_admin),
    db: AsyncSession = Depends(get_staff_db),
) -> Service:
    service = Service(
        tenant_id=admin.tenant_id,
        name=payload.name,
        duration_minutes=payload.duration_minutes,
        price_cents=payload.price_cents,
    )
    db.add(service)
    await db.flush()
    return service


@router.put("/services/{service_id}", response_model=ServiceOut)
async def update_service(
    service_id: UUID,
    payload: ServiceUpdate,
    admin: CurrentStaff = Depends(require_admin),
    db: AsyncSession = Depends(get_staff_db),
) -> Service:
    service = await db.get(Service, service_id)
    if service is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Serviço não encontrado")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(service, field, value)

    await db.flush()
    return service


# --- Promoções (RF-ADM-04) -------------------------------------------------


@router.get("/promotions", response_model=list[PromotionOut])
async def list_promotions(
    admin: CurrentStaff = Depends(require_admin),
    db: AsyncSession = Depends(get_staff_db),
) -> list[Promotion]:
    result = await db.execute(select(Promotion).order_by(Promotion.starts_at.desc()))
    return list(result.scalars().all())


@router.post("/promotions", response_model=PromotionOut, status_code=status.HTTP_201_CREATED)
async def create_promotion(
    payload: PromotionCreate,
    admin: CurrentStaff = Depends(require_admin),
    db: AsyncSession = Depends(get_staff_db),
) -> Promotion:
    promotion = Promotion(tenant_id=admin.tenant_id, **payload.model_dump())
    db.add(promotion)
    await db.flush()
    return promotion


@router.put("/promotions/{promotion_id}", response_model=PromotionOut)
async def update_promotion(
    promotion_id: UUID,
    payload: PromotionUpdate,
    admin: CurrentStaff = Depends(require_admin),
    db: AsyncSession = Depends(get_staff_db),
) -> Promotion:
    promotion = await db.get(Promotion, promotion_id)
    if promotion is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Promoção não encontrada")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(promotion, field, value)

    await db.flush()
    return promotion


# --- Agenda completa (RF-ADM-05) -------------------------------------------


@router.get("/agenda", response_model=list[AgendaAppointmentOut])
async def get_full_agenda(
    date: date_type = Query(default_factory=lambda: datetime.now(timezone.utc).date()),
    admin: CurrentStaff = Depends(require_admin),
    db: AsyncSession = Depends(get_staff_db),
) -> list[AgendaAppointmentOut]:
    start, end = day_range(date)
    rows = await get_agenda_rows(db, start=start, end=end)
    return serialize_agenda_rows(rows)
