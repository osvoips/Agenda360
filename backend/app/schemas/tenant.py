from pydantic import BaseModel


class TenantOut(BaseModel):
    slug: str
    display_name: str
    logo_url: str | None = None
    icon_url: str | None = None
    primary_color: str | None = None
    secondary_color: str | None = None
    min_cancel_notice_minutes: int
