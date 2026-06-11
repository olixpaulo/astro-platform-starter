class TestAuth:
    async def test_register_creates_user(self, client):
        response = await client.post(
            "/api/v1/auth/register",
            json={"email": "novo@example.com", "password": "senhaSegura1", "full_name": "Novo Utilizador"},
        )
        assert response.status_code == 201
        body = response.json()
        assert body["email"] == "novo@example.com"
        assert "hashed_password" not in body

    async def test_register_duplicate_email_rejected(self, client):
        payload = {"email": "dup@example.com", "password": "senhaSegura1"}
        assert (await client.post("/api/v1/auth/register", json=payload)).status_code == 201
        assert (await client.post("/api/v1/auth/register", json=payload)).status_code == 409

    async def test_register_weak_password_rejected(self, client):
        response = await client.post(
            "/api/v1/auth/register", json={"email": "x@example.com", "password": "curta"}
        )
        assert response.status_code == 422

    async def test_login_returns_token_pair(self, client):
        await client.post("/api/v1/auth/register", json={"email": "a@example.com", "password": "senhaSegura1"})
        response = await client.post(
            "/api/v1/auth/login", json={"email": "a@example.com", "password": "senhaSegura1"}
        )
        assert response.status_code == 200
        body = response.json()
        assert body["access_token"] and body["refresh_token"]

    async def test_login_wrong_password_rejected(self, client):
        await client.post("/api/v1/auth/register", json={"email": "b@example.com", "password": "senhaSegura1"})
        response = await client.post(
            "/api/v1/auth/login", json={"email": "b@example.com", "password": "errada123"}
        )
        assert response.status_code == 401

    async def test_refresh_rotates_tokens(self, client, auth_headers):
        _, tokens = auth_headers
        response = await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
        assert response.status_code == 200
        # O refresh token antigo foi revogado pela rotação
        reuse = await client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
        assert reuse.status_code == 401

    async def test_me_requires_auth(self, client):
        assert (await client.get("/api/v1/users/me")).status_code == 401

    async def test_me_returns_profile(self, client, auth_headers):
        headers, _ = auth_headers
        response = await client.get("/api/v1/users/me", headers=headers)
        assert response.status_code == 200
        assert response.json()["email"] == "user@example.com"

    async def test_forgot_password_does_not_leak_accounts(self, client):
        response = await client.post(
            "/api/v1/auth/forgot-password", json={"email": "naoexiste@example.com"}
        )
        assert response.status_code == 200
