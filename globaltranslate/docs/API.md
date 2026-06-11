# GlobalTranslate — Documentação da API

Base URL: `https://<host>/api/v1` · Documentação interativa (OpenAPI): `GET /docs`

## Autenticação

Todos os endpoints (exceto `/auth/*`, `/translations/languages` e `/subscriptions/plans`) requerem o header:

```
Authorization: Bearer <access_token>
```

O access token expira em 30 minutos; use `/auth/refresh` com o refresh token (rotativo — cada uso revoga o anterior).

### POST /auth/register
```json
{ "email": "user@example.com", "password": "minimo8chars", "full_name": "Nome" }
```
→ `201` perfil do utilizador · `409` email duplicado

### POST /auth/login
```json
{ "email": "user@example.com", "password": "..." }
```
→ `200 { "access_token", "refresh_token", "token_type": "bearer" }`

### POST /auth/refresh · POST /auth/logout
```json
{ "refresh_token": "..." }
```

### POST /auth/forgot-password → envia código por email (resposta neutra, anti-enumeração)
### POST /auth/reset-password `{ "token", "new_password" }`

## Utilizadores

| Método | Endpoint | Descrição |
|---|---|---|
| GET | /users/me | Perfil atual |
| PATCH | /users/me | Atualizar nome, idiomas preferidos, avatar |
| POST | /users/me/change-password | `{ current_password, new_password }` |
| DELETE | /users/me | Eliminar conta |

## Traduções

### GET /translations/languages
Lista 100+ idiomas: `[{ code, name, native_name, supports_tts, supports_ocr, supports_offline }]`

### POST /translations
```json
{ "text": "olá mundo", "source_lang": "auto", "target_lang": "en", "context": "saudação informal", "save_history": true }
```
→ `200`
```json
{ "id": "...", "detected_lang": "pt", "translated_text": "hello world", "alternatives": ["hi world"], "cached": false }
```
Erros: `429` rate limit · `402` quota diária do plano gratuito excedida.

### POST /translations/detect `{ "text" }` → `{ "language": "pt", "confidence": 0.98 }`
### POST /translations/suggest `{ "text", "target_lang" }` → `{ "suggestions": [...] }`

### GET /translations/history?page=1&page_size=20&search=...&favorites_only=false
→ `{ items: [...], total, page, page_size }`

### POST /translations/{id}/favorite · DELETE /translations/{id}/favorite · DELETE /translations/{id}

## Voz

### POST /voice/tts
```json
{ "text": "hello", "language": "en", "voice_gender": "female|male", "speed": 1.0, "premium_voice": false }
```
→ `200 audio/mpeg` (bytes MP3) · `402` se `premium_voice` sem plano Premium

### POST /voice/stt — multipart: `audio` (≤25MB), `language` (opcional)
→ `{ "text": "...", "language": "en" }`

### POST /voice/translate — multipart: `audio`, `source_lang`, `target_lang`
Pipeline completo voz→texto→tradução:
→ `{ "recognized_text", "detected_lang", "translated_text", "target_lang" }`

## OCR (tradução por câmara)

### POST /ocr/translate — multipart: `image` (JPEG/PNG/WebP/HEIC ≤10MB), `target_lang`
→
```json
{
  "detected_lang": "en",
  "full_text": "...",
  "translated_text": "...",
  "blocks": [{ "text", "translated_text", "x", "y", "width", "height" }]
}
```
As coordenadas dos blocos são normalizadas (0..1) para sobreposição na imagem.

## Documentos

| Método | Endpoint | Descrição |
|---|---|---|
| POST | /documents | multipart: `file` (PDF/DOCX/TXT/PPTX), `source_lang`, `target_lang` → `202` processamento assíncrono |
| GET | /documents | Lista os documentos do utilizador |
| GET | /documents/{id} | Estado + texto traduzido |
| GET | /documents/{id}/download | Download da tradução (text/plain) |
| DELETE | /documents/{id} | Eliminar |

Limites: 5MB (free) / 50MB (premium).

## Subscrições

| Método | Endpoint | Descrição |
|---|---|---|
| GET | /subscriptions/plans | Planos disponíveis (público) |
| GET | /subscriptions/me | Subscrição ativa |
| POST | /subscriptions | `{ plan_tier: "premium", payment_method_token }` |
| DELETE | /subscriptions/me | Cancelar |
| GET | /subscriptions/payments | Histórico de pagamentos |

## Admin (requer role `admin`)

| Método | Endpoint | Descrição |
|---|---|---|
| GET | /admin/stats | Utilizadores, traduções, receita, top pares de idiomas |
| GET | /admin/users?page&search | Gestão de utilizadores |
| PATCH | /admin/users/{id} | `{ is_active, role }` |
| GET | /admin/plans · PATCH /admin/plans/{id} | Gestão de planos |
| GET | /admin/logs?action&user_id | Logs de utilização |
| GET | /admin/reports/translations-by-day?days=30 | Relatório temporal |

Painel web: `GET /admin/panel`.

## Erros

Formato uniforme: `{ "detail": "mensagem" }` com códigos HTTP standard
(`401`, `402`, `403`, `404`, `409`, `413`, `415`, `422`, `429`).

## Rate limiting

Janela deslizante por utilizador/IP em Redis: 20 req/min (free), 120 req/min (premium).
Resposta `429` inclui header `Retry-After`.
