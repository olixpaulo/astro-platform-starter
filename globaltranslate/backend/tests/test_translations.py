class TestTranslations:
    async def test_translate_requires_auth(self, client):
        response = await client.post(
            "/api/v1/translations", json={"text": "olá", "target_lang": "en"}
        )
        assert response.status_code == 401

    async def test_translate_text(self, client, auth_headers):
        headers, _ = auth_headers
        response = await client.post(
            "/api/v1/translations",
            json={"text": "olá mundo", "source_lang": "auto", "target_lang": "en"},
            headers=headers,
        )
        assert response.status_code == 200
        body = response.json()
        assert body["translated_text"] == "[en] olá mundo"
        assert body["detected_lang"] == "pt"
        assert body["id"]

    async def test_translate_saves_history(self, client, auth_headers):
        headers, _ = auth_headers
        await client.post(
            "/api/v1/translations",
            json={"text": "bom dia", "target_lang": "fr"},
            headers=headers,
        )
        response = await client.get("/api/v1/translations/history", headers=headers)
        assert response.status_code == 200
        body = response.json()
        assert body["total"] == 1
        assert body["items"][0]["source_text"] == "bom dia"

    async def test_history_search(self, client, auth_headers):
        headers, _ = auth_headers
        for text in ["maçã verde", "laranja doce"]:
            await client.post("/api/v1/translations", json={"text": text, "target_lang": "en"}, headers=headers)
        response = await client.get("/api/v1/translations/history?search=laranja", headers=headers)
        body = response.json()
        assert body["total"] == 1
        assert "laranja" in body["items"][0]["source_text"]

    async def test_favorites_flow(self, client, auth_headers):
        headers, _ = auth_headers
        translate = await client.post(
            "/api/v1/translations", json={"text": "favorito", "target_lang": "de"}, headers=headers
        )
        translation_id = translate.json()["id"]

        assert (
            await client.post(f"/api/v1/translations/{translation_id}/favorite", headers=headers)
        ).status_code == 200

        favorites = await client.get("/api/v1/translations/history?favorites_only=true", headers=headers)
        assert favorites.json()["total"] == 1
        assert favorites.json()["items"][0]["is_favorite"] is True

        assert (
            await client.delete(f"/api/v1/translations/{translation_id}/favorite", headers=headers)
        ).status_code == 200
        favorites = await client.get("/api/v1/translations/history?favorites_only=true", headers=headers)
        assert favorites.json()["total"] == 0

    async def test_detect_language(self, client, auth_headers):
        headers, _ = auth_headers
        response = await client.post("/api/v1/translations/detect", json={"text": "olá"}, headers=headers)
        assert response.status_code == 200
        assert response.json()["language"] == "pt"

    async def test_empty_text_rejected(self, client, auth_headers):
        headers, _ = auth_headers
        response = await client.post(
            "/api/v1/translations", json={"text": "", "target_lang": "en"}, headers=headers
        )
        assert response.status_code == 422


class TestSubscriptions:
    async def test_list_plans_public(self, client):
        response = await client.get("/api/v1/subscriptions/plans")
        assert response.status_code == 200
        tiers = {p["tier"] for p in response.json()}
        assert {"free", "premium"} <= tiers

    async def test_subscribe_premium(self, client, auth_headers):
        headers, _ = auth_headers
        response = await client.post(
            "/api/v1/subscriptions",
            json={"plan_tier": "premium", "payment_method_token": "tok_test"},
            headers=headers,
        )
        assert response.status_code == 201
        assert response.json()["plan"]["tier"] == "premium"

        me = await client.get("/api/v1/subscriptions/me", headers=headers)
        assert me.json()["status"] == "active"

    async def test_admin_endpoints_forbidden_for_regular_user(self, client, auth_headers):
        headers, _ = auth_headers
        response = await client.get("/api/v1/admin/stats", headers=headers)
        assert response.status_code == 403
