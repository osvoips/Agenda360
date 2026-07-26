import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AppointmentCreate(BaseModel):
    client_name: str = Field(min_length=1, max_length=200)
    client_phone: str = Field(min_length=8, max_length=30)
    service_id: uuid.UUID
    professional_id: uuid.UUID
    starts_at: datetime


class AppointmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    client_id: uuid.UUID
    professional_id: uuid.UUID
    service_id: uuid.UUID
    starts_at: datetime
    ends_at: datetime
    status: str


class AppointmentCancelRequest(BaseModel):
    phone: str = Field(min_length=8, max_length=30)


class AppointmentStaffCancelRequest(BaseModel):
    reason: str | None = Field(default=None, max_length=500)


class AgendaAppointmentOut(BaseModel):
    id: uuid.UUID
    professional_id: uuid.UUID
    service_id: uuid.UUID
    client_name: str
    client_phone: str
    starts_at: datetime
    ends_at: datetime
    status: str
