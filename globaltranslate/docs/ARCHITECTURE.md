# Arquitetura — GlobalTranslate

## Visão geral

```
┌────────────────────────────┐
│   Flutter (Android/iOS/Web)│
│   Riverpod + Go Router     │
└────────────┬───────────────┘
             │ HTTPS / JSON (JWT)
┌────────────▼───────────────┐      ┌──────────────┐
│   FastAPI  /api/v1         │─────▶│  OpenAI      │
│   auth · translations ·    │      │  GPT (tradução/OCR)
│   voice · ocr · documents ·│      │  Whisper (STT)
│   subscriptions · admin    │      │  TTS         │
└─────┬──────────────┬───────┘      └──────────────┘
      │              │
┌─────▼─────┐  ┌─────▼─────┐
│ PostgreSQL│  │   Redis    │
│ (dados)   │  │ cache/rate │
└───────────┘  └────────────┘
```

## Backend — Clean Architecture

| Camada | Pasta | Responsabilidade |
|---|---|---|
| Apresentação | `app/api/v1/` | Routers HTTP, validação (Pydantic), códigos de estado |
| Aplicação | `app/services/` | Casos de uso: tradução, voz, OCR, documentos, quotas |
| Domínio | `app/db/models.py`, `app/schemas/` | Entidades e contratos |
| Infraestrutura | `app/core/`, `app/db/session.py` | Config, JWT, criptografia, Redis, sessão BD |

Princípios aplicados:
- **SRP**: cada serviço cobre um caso de uso; routers só orquestram.
- **DIP**: routers dependem de serviços e de dependências injetadas (`Depends`), não de implementações concretas; os testes substituem BD (SQLite) e IA (mocks) sem tocar nos routers.
- **OCP**: novos fornecedores de tradução implementam a mesma interface (`translate_text(text, source, target, context) -> dict`).

## Decisões relevantes

- **Cache de traduções** (Redis, 24h, chave = hash do texto+par de idiomas) corta custo e latência da tradução em tempo real enquanto o utilizador escreve; o debounce no cliente (450ms) reduz chamadas.
- **Refresh tokens rotativos** persistidos como hash SHA-256 — roubo de BD não expõe tokens; reutilização de um token rodado é negada.
- **Documentos processados em background** (`BackgroundTasks`) com estado consultável — uploads grandes não bloqueiam o pedido. Para escala maior, trocar por fila (Celery/ARQ) sem mudar a API.
- **OCR com bounding boxes normalizados** permite à app sobrepor traduções na imagem em qualquer resolução.
- **Rate limiting fail-open**: indisponibilidade do Redis degrada (sem limites) em vez de derrubar o serviço.
- **Dados sensíveis de pagamento** cifrados com Fernet (`ENCRYPTION_KEY`) antes de persistir.

## Frontend — features-first

```
lib/
├── core/          # router, tema M3, cliente HTTP (Dio + refresh automático), storage seguro
├── shared/        # widgets reutilizáveis (LanguageBar, TtsButton)
└── features/<x>/
    ├── data/          # repositórios (HTTP)
    ├── domain/        # modelos imutáveis
    ├── providers/     # estado Riverpod
    └── presentation/  # ecrãs
```

- **Riverpod** para estado (AsyncNotifier para sessão, Notifier para tradução/definições).
- **Go Router** com `StatefulShellRoute` (5 separadores) e redirect de autenticação.
- **Acessibilidade**: dark mode, alto contraste (ColorScheme `contrastLevel`), tooltips/labels para leitores de ecrã.

## Segurança

- JWT HS256 com expiração curta + refresh rotativo; senhas com bcrypt.
- Headers de segurança (HSTS, nosniff, X-Frame-Options DENY) via middleware.
- CORS restrito por configuração; validação estrita de uploads (tipo + tamanho).
- Anti-enumeração de contas no forgot-password; tokens de reset com hash + uso único + TTL 30min.
- Rate limiting por utilizador e por IP.
