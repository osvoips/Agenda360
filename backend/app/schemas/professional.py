import uuid

from pydantic import BaseModel, ConfigDict, Field


class ProfessionalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    phone: str | None
    is_active: bool


class ProfessionalCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    phone: str | None = Field(default=None, max_length=30)
    service_ids: list[uuid.UUID] = Field(default_factory=list)


class ProfessionalUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    phone: str | None = Field(default=None, max_length=30)
    is_active: bool | None = None
    service_ids: list[uuid.UUID] | None = None
