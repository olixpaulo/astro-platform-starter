from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.schemas.user import UserOut


class AdminStats(BaseModel):
    total_users: int
    active_users_30d: int
    premium_users: int
    translations_today: int
    translations_total: int
    revenue_month_cents: int
    top_language_pairs: list[dict]


class AdminUserUpdate(BaseModel):
    is_active: bool | None = None
    role: str | None = None


class UsersPage(BaseModel):
    items: list[UserOut]
    total: int
    page: int
    page_size: int


class UsageLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: str | None
    action: str
    detail: str | None
    ip_address: str | None
    created_at: datetime


class LogsPage(BaseModel):
    items: list[UsageLogOut]
    total: int
    page: int
    page_size: int


class PlanUpdate(BaseModel):
    name: str | None = None
    price_monthly_cents: int | None = None
    daily_translation_limit: int | None = None
    max_document_size_mb: int | None = None
    premium_voices: bool | None = None
    ads_free: bool | None = None
    is_active: bool | None = None
