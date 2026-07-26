import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class PromotionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    service_id: uuid.UUID
    name: str
    discount_type: str
    discount_value: int
    starts_at: datetime
    ends_at: datetime
    is_active: bool


class PromotionCreate(BaseModel):
    service_id: uuid.UUID
    name: str = Field(min_length=1, max_length=200)
    discount_type: Literal["percentage", "fixed"]
    discount_value: int = Field(ge=0)
    starts_at: datetime
    ends_at: datetime


class PromotionUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    discount_type: Literal["percentage", "fixed"] | None = None
    discount_value: int | None = Field(default=None, ge=0)
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    is_active: bool | None = None
