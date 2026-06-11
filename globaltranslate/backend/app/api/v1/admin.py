from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import distinct, func, select

from app.api.deps import CurrentAdmin, DbSession
from app.db.models import (
    Payment,
    PaymentStatus,
    Plan,
    PlanTier,
    Subscription,
    SubscriptionStatus,
    Translation,
    UsageLog,
    User,
    UserRole,
)
from app.schemas.admin import AdminStats, AdminUserUpdate, LogsPage, PlanUpdate, UsersPage
from app.schemas.subscription import PlanOut
from app.schemas.user import UserOut

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/stats", response_model=AdminStats)
async def stats(admin: CurrentAdmin, db: DbSession):
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    total_users = (await db.execute(select(func.count(User.id)))).scalar_one()
    active_users_30d = (
        await db.execute(
            select(func.count(distinct(UsageLog.user_id))).where(UsageLog.created_at >= now - timedelta(days=30))
        )
    ).scalar_one()
    premium_users = (
        await db.execute(
            select(func.count(distinct(Subscription.user_id)))
            .join(Plan, Subscription.plan_id == Plan.id)
            .where(Subscription.status == SubscriptionStatus.active, Plan.tier != PlanTier.free)
        )
    ).scalar_one()
    translations_today = (
        await db.execute(select(func.count(Translation.id)).where(Translation.created_at >= today_start))
    ).scalar_one()
    translations_total = (await db.execute(select(func.count(Translation.id)))).scalar_one()
    revenue_month = (
        await db.execute(
            select(func.coalesce(func.sum(Payment.amount), 0)).where(
                Payment.status == PaymentStatus.succeeded, Payment.created_at >= month_start
            )
        )
    ).scalar_one()

    pairs_result = await db.execute(
        select(Translation.source_lang, Translation.target_lang, func.count(Translation.id).label("count"))
        .group_by(Translation.source_lang, Translation.target_lang)
        .order_by(func.count(Translation.id).desc())
        .limit(10)
    )
    top_pairs = [{"source": s, "target": t, "count": c} for s, t, c in pairs_result]

    return AdminStats(
        total_users=total_users,
        active_users_30d=active_users_30d,
        premium_users=premium_users,
        translations_today=translations_today,
        translations_total=translations_total,
        revenue_month_cents=int(revenue_month * 100),
        top_language_pairs=top_pairs,
    )


@router.get("/users", response_model=UsersPage)
async def list_users(
    admin: CurrentAdmin,
    db: DbSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: str | None = None,
):
    query = select(User)
    count_query = select(func.count(User.id))
    if search:
        pattern = f"%{search}%"
        condition = User.email.ilike(pattern) | User.full_name.ilike(pattern)
        query = query.where(condition)
        count_query = count_query.where(condition)

    total = (await db.execute(count_query)).scalar_one()
    result = await db.execute(query.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size))
    return UsersPage(
        items=[UserOut.model_validate(u) for u in result.scalars()],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.patch("/users/{user_id}", response_model=UserOut)
async def update_user(user_id: str, payload: AdminUserUpdate, admin: CurrentAdmin, db: DbSession):
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Utilizador não encontrado")
    if payload.is_active is not None:
        if user.id == admin.id and not payload.is_active:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Não pode desativar a própria conta")
        user.is_active = payload.is_active
    if payload.role is not None:
        try:
            user.role = UserRole(payload.role)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Role inválido")
    await db.commit()
    await db.refresh(user)
    return user


@router.get("/plans", response_model=list[PlanOut])
async def list_all_plans(admin: CurrentAdmin, db: DbSession):
    result = await db.execute(select(Plan).order_by(Plan.price_monthly_cents))
    return result.scalars().all()


@router.patch("/plans/{plan_id}", response_model=PlanOut)
async def update_plan(plan_id: str, payload: PlanUpdate, admin: CurrentAdmin, db: DbSession):
    plan = await db.get(Plan, plan_id)
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plano não encontrado")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(plan, field, value)
    await db.commit()
    await db.refresh(plan)
    return plan


@router.get("/logs", response_model=LogsPage)
async def list_logs(
    admin: CurrentAdmin,
    db: DbSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    action: str | None = None,
    user_id: str | None = None,
):
    query = select(UsageLog)
    count_query = select(func.count(UsageLog.id))
    if action:
        query = query.where(UsageLog.action == action)
        count_query = count_query.where(UsageLog.action == action)
    if user_id:
        query = query.where(UsageLog.user_id == user_id)
        count_query = count_query.where(UsageLog.user_id == user_id)

    total = (await db.execute(count_query)).scalar_one()
    result = await db.execute(
        query.order_by(UsageLog.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    )
    return LogsPage(items=list(result.scalars()), total=total, page=page, page_size=page_size)


@router.get("/reports/translations-by-day")
async def translations_by_day(admin: CurrentAdmin, db: DbSession, days: int = Query(30, ge=1, le=365)):
    since = datetime.now(timezone.utc) - timedelta(days=days)
    result = await db.execute(
        select(func.date(Translation.created_at).label("day"), func.count(Translation.id))
        .where(Translation.created_at >= since)
        .group_by(func.date(Translation.created_at))
        .order_by(func.date(Translation.created_at))
    )
    return [{"day": str(day), "count": count} for day, count in result]
