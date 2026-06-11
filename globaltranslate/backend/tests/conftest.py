import os

os.environ.setdefault("DATABASE_URL_OVERRIDE", "sqlite+aiosqlite://")
os.environ.setdefault("SECRET_KEY", "test-secret-key")
os.environ.setdefault("OPENAI_API_KEY", "sk-test")

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.db.models import Base, Plan, PlanTier
from app.db.session import get_db
from app.main import app


@pytest.fixture
async def db_engine():
    engine = create_async_engine(
        "sqlite+aiosqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest.fixture
async def db_session_factory(db_engine):
    factory = async_sessionmaker(db_engine, expire_on_commit=False)
    async with factory() as session:
        session.add_all(
            [
                Plan(tier=PlanTier.free, name="Gratuito", price_monthly_cents=0, daily_translation_limit=100),
                Plan(tier=PlanTier.premium, name="Premium", price_monthly_cents=799, premium_voices=True, ads_free=True),
            ]
        )
        await session.commit()
    return factory


@pytest.fixture
async def client(db_session_factory, monkeypatch):
    async def override_get_db():
        async with db_session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db

    # Sem Redis nos testes: rate limit e quotas fazem fail-open
    async def fake_translate(text, source_lang, target_lang, context=None):
        return {
            "translated_text": f"[{target_lang}] {text}",
            "detected_lang": "pt" if source_lang == "auto" else source_lang,
            "alternatives": [],
            "cached": False,
        }

    async def fake_detect(text):
        return {"language": "pt", "confidence": 0.97}

    async def fake_suggest(text, target_lang):
        return [f"{text}…"]

    from app.services import translation_service

    monkeypatch.setattr(translation_service, "translate_text", fake_translate)
    monkeypatch.setattr(translation_service, "detect_language", fake_detect)
    monkeypatch.setattr(translation_service, "smart_suggestions", fake_suggest)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest.fixture
async def auth_headers(client):
    await client.post(
        "/api/v1/auth/register",
        json={"email": "user@example.com", "password": "password123", "full_name": "Test User"},
    )
    response = await client.post(
        "/api/v1/auth/login", json={"email": "user@example.com", "password": "password123"}
    )
    tokens = response.json()
    return {"Authorization": f"Bearer {tokens['access_token']}"}, tokens
