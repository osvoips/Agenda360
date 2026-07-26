import uuid

from pydantic import BaseModel, ConfigDict, Field


class ServiceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    duration_minutes: int
    price_cents: int | None
    is_active: bool


class ServiceCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    duration_minutes: int = Field(gt=0)
    price_cents: int | None = Field(default=None, ge=0)


class ServiceUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    duration_minutes: int | None = Field(default=None, gt=0)
    price_cents: int | None = Field(default=None, ge=0)
    is_active: bool | None = None
