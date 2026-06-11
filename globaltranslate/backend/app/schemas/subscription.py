from datetime import datetime

from pydantic import BaseModel, ConfigDict


class PlanOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    tier: str
    name: str
    price_monthly_cents: int
    currency: str
    daily_translation_limit: int | None
    max_document_size_mb: int
    premium_voices: bool
    ads_free: bool


class SubscriptionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    status: str
    current_period_start: datetime
    current_period_end: datetime | None
    plan: PlanOut


class SubscribeRequest(BaseModel):
    plan_tier: str
    payment_method_token: str | None = None


class PaymentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    amount: float
    currency: str
    status: str
    created_at: datetime
