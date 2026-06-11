import json
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.deps import CurrentUser, DbSession
from app.core.security import encrypt_sensitive
from app.db.models import Payment, PaymentStatus, Plan, PlanTier, Subscription, SubscriptionStatus
from app.schemas.auth import MessageResponse
from app.schemas.subscription import PaymentOut, PlanOut, SubscribeRequest, SubscriptionOut
from app.services.usage_service import log_action

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])


@router.get("/plans", response_model=list[PlanOut])
async def list_plans(db: DbSession):
    result = await db.execute(select(Plan).where(Plan.is_active).order_by(Plan.price_monthly_cents))
    return result.scalars().all()


@router.get("/me", response_model=SubscriptionOut | None)
async def my_subscription(user: CurrentUser, db: DbSession):
    result = await db.execute(
        select(Subscription)
        .options(selectinload(Subscription.plan))
        .where(Subscription.user_id == user.id, Subscription.status == SubscriptionStatus.active)
        .order_by(Subscription.created_at.desc())
    )
    return result.scalars().first()


@router.post("", response_model=SubscriptionOut, status_code=status.HTTP_201_CREATED)
async def subscribe(payload: SubscribeRequest, user: CurrentUser, db: DbSession, request: Request):
    try:
        tier = PlanTier(payload.plan_tier)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Plano inválido")

    plan_result = await db.execute(select(Plan).where(Plan.tier == tier, Plan.is_active))
    plan = plan_result.scalar_one_or_none()
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plano não disponível")

    # Cancela subscrição ativa anterior (upgrade/downgrade)
    active = await db.execute(
        select(Subscription).where(
            Subscription.user_id == user.id, Subscription.status == SubscriptionStatus.active
        )
    )
    for sub in active.scalars():
        sub.status = SubscriptionStatus.canceled

    now = datetime.now(timezone.utc)
    subscription = Subscription(
        user_id=user.id,
        plan_id=plan.id,
        current_period_start=now,
        current_period_end=now + timedelta(days=30),
    )
    db.add(subscription)
    await db.flush()

    if plan.price_monthly_cents > 0:
        # Em produção o pagamento é confirmado pelo webhook do Stripe; aqui regista-se a intenção
        payment = Payment(
            user_id=user.id,
            subscription_id=subscription.id,
            amount=plan.price_monthly_cents / 100,
            currency=plan.currency,
            status=PaymentStatus.succeeded if payload.payment_method_token else PaymentStatus.pending,
            encrypted_payment_metadata=(
                encrypt_sensitive(json.dumps({"payment_method_token": payload.payment_method_token}))
                if payload.payment_method_token
                else None
            ),
        )
        db.add(payment)

    await db.commit()
    await log_action(db, "subscription.created", user.id, detail=tier.value, request=request)

    result = await db.execute(
        select(Subscription).options(selectinload(Subscription.plan)).where(Subscription.id == subscription.id)
    )
    return result.scalar_one()


@router.delete("/me", response_model=MessageResponse)
async def cancel_subscription(user: CurrentUser, db: DbSession, request: Request):
    result = await db.execute(
        select(Subscription).where(
            Subscription.user_id == user.id, Subscription.status == SubscriptionStatus.active
        )
    )
    subscription = result.scalars().first()
    if subscription is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sem subscrição ativa")
    subscription.status = SubscriptionStatus.canceled
    await db.commit()
    await log_action(db, "subscription.canceled", user.id, request=request)
    return MessageResponse(message="Subscrição cancelada")


@router.get("/payments", response_model=list[PaymentOut])
async def my_payments(user: CurrentUser, db: DbSession):
    result = await db.execute(
        select(Payment).where(Payment.user_id == user.id).order_by(Payment.created_at.desc())
    )
    return result.scalars().all()
