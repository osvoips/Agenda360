import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class BlockedSlotCreate(BaseModel):
    professional_id: uuid.UUID
    starts_at: datetime
    ends_at: datetime
    reason: str | None = Field(default=None, max_length=300)


class BlockedSlotOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    professional_id: uuid.UUID
    starts_at: datetime
    ends_at: datetime
    reason: str | None
