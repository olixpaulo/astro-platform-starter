# GlobalTranslate 🌍

Plataforma moderna de tradução multilíngue com IA generativa, para **Android, iOS e Web** — semelhante ao Google Translate e DeepL, com funcionalidades avançadas de IA.

## Stack

| Camada | Tecnologia |
|---|---|
| Frontend | Flutter 3.x · Material Design 3 · Riverpod · Go Router |
| Backend | Python FastAPI · SQLAlchemy 2 (async) · Pydantic v2 |
| Base de dados | PostgreSQL 16 |
| Cache / Rate limit | Redis 7 |
| IA | OpenAI (tradução contextual, STT Whisper, TTS, OCR/Vision) |
| Infra | Docker · Docker Compose · GitHub Actions CI/CD |

## Funcionalidades

- ✅ Tradução de texto entre 100+ idiomas com deteção automática
- ✅ Tradução em tempo real enquanto escreve (debounce + cache Redis)
- ✅ Text-to-Speech (voz masculina/feminina, controlo de velocidade)
- ✅ Speech-to-Text (tradução por voz)
- ✅ Modo conversação (duas pessoas, interface dividida)
- ✅ Tradução por câmara (OCR + sobreposição)
- ✅ Tradução de documentos (PDF, DOCX, TXT, PPTX)
- ✅ Histórico, pesquisa e favoritos
- ✅ Modo offline (pacotes de idiomas)
- ✅ Autenticação JWT + Refresh Token, recuperação de senha
- ✅ Planos Premium e pagamentos
- ✅ Painel administrativo web (utilizadores, estatísticas, planos, logs)

## Estrutura

```
globaltranslate/
├── backend/          # FastAPI (Clean Architecture)
│   ├── app/
│   │   ├── api/v1/   # Routers: auth, users, translations, voice, ocr, documents, subscriptions, admin
│   │   ├── core/     # Config, segurança JWT, rate limiting, Redis
│   │   ├── db/       # Sessão, modelos SQLAlchemy
│   │   ├── schemas/  # Pydantic
│   │   ├── services/ # Tradução IA, voz, OCR, documentos
│   │   └── admin_panel/  # Dashboard web administrativo
│   ├── db/init.sql   # Esquema PostgreSQL
│   └── tests/        # Pytest
├── frontend/         # Flutter (features-first + Clean Architecture)
│   └── lib/
│       ├── core/     # Router, tema, API client, storage
│       └── features/ # auth, translation, voice, conversation, camera, documents, history, offline, settings, premium
├── docs/             # API.md, DEPLOYMENT.md, ARCHITECTURE.md
├── scripts/          # install.sh, deploy_vps.sh
└── docker-compose.yml
```

## Arranque rápido

```bash
cp .env.example .env          # preencher OPENAI_API_KEY e segredos
./scripts/install.sh          # valida dependências e prepara ambiente
docker compose up -d --build  # postgres + redis + api
```

- API: http://localhost:8000 · Docs interativas: http://localhost:8000/docs
- Painel admin: http://localhost:8000/admin/panel
- Frontend: `cd frontend && flutter run` (ou `flutter run -d chrome`)

## Testes

```bash
cd backend && pip install -r requirements.txt -r requirements-dev.txt && pytest
cd frontend && flutter test
```

## Documentação

- [Documentação da API](docs/API.md)
- [Guia de implantação (VPS e Cloud)](docs/DEPLOYMENT.md)
- [Arquitetura](docs/ARCHITECTURE.md)
