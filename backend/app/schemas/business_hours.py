from datetime import time

from pydantic import BaseModel, ConfigDict, model_validator


class BusinessHoursItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    weekday: int
    opens_at: time | None
    closes_at: time | None
    is_closed: bool

    @model_validator(mode="after")
    def _validate_hours(self) -> "BusinessHoursItem":
        if not self.is_closed and (self.opens_at is None or self.closes_at is None or self.opens_at >= self.closes_at):
            raise ValueError("opens_at deve ser anterior a closes_at quando o dia não está fechado")
        return self


class BusinessHoursUpdate(BaseModel):
    days: list[BusinessHoursItem]
