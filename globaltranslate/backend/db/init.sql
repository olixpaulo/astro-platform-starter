-- =====================================================================
-- GlobalTranslate — Esquema PostgreSQL 16
-- Executado automaticamente pelo Docker no primeiro arranque.
-- =====================================================================

CREATE TYPE user_role AS ENUM ('user', 'admin');
CREATE TYPE plan_tier AS ENUM ('free', 'premium', 'business');
CREATE TYPE subscription_status AS ENUM ('active', 'canceled', 'past_due', 'expired');
CREATE TYPE payment_status AS ENUM ('pending', 'succeeded', 'failed', 'refunded');
CREATE TYPE translation_source AS ENUM ('text', 'voice', 'camera', 'document', 'conversation');
CREATE TYPE document_status AS ENUM ('processing', 'completed', 'failed');

-- ---------------------------------------------------------------------
CREATE TABLE users (
    id                      VARCHAR(36) PRIMARY KEY,
    email                   VARCHAR(255) NOT NULL UNIQUE,
    hashed_password         VARCHAR(255) NOT NULL,
    full_name               VARCHAR(255) NOT NULL DEFAULT '',
    role                    user_role NOT NULL DEFAULT 'user',
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified             BOOLEAN NOT NULL DEFAULT FALSE,
    preferred_source_lang   VARCHAR(10) NOT NULL DEFAULT 'auto',
    preferred_target_lang   VARCHAR(10) NOT NULL DEFAULT 'en',
    avatar_url              VARCHAR(512),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_users_email ON users (email);

CREATE TABLE refresh_tokens (
    id          VARCHAR(36) PRIMARY KEY,
    user_id     VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  VARCHAR(64) NOT NULL UNIQUE,
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens (user_id);

CREATE TABLE password_reset_tokens (
    id          VARCHAR(36) PRIMARY KEY,
    user_id     VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  VARCHAR(64) NOT NULL UNIQUE,
    expires_at  TIMESTAMPTZ NOT NULL,
    used        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE languages (
    code             VARCHAR(10) PRIMARY KEY,
    name             VARCHAR(100) NOT NULL,
    native_name      VARCHAR(100) NOT NULL DEFAULT '',
    supports_tts     BOOLEAN NOT NULL DEFAULT TRUE,
    supports_ocr     BOOLEAN NOT NULL DEFAULT TRUE,
    supports_offline BOOLEAN NOT NULL DEFAULT FALSE,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE translations (
    id              VARCHAR(36) PRIMARY KEY,
    user_id         VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    source_lang     VARCHAR(10) NOT NULL,
    target_lang     VARCHAR(10) NOT NULL,
    detected_lang   VARCHAR(10),
    source_text     TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    source          translation_source NOT NULL DEFAULT 'text',
    char_count      INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_translations_user_created ON translations (user_id, created_at DESC);
-- Pesquisa full-text no histórico
CREATE INDEX idx_translations_search ON translations
    USING GIN (to_tsvector('simple', source_text || ' ' || translated_text));

CREATE TABLE favorites (
    id             VARCHAR(36) PRIMARY KEY,
    user_id        VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    translation_id VARCHAR(36) NOT NULL REFERENCES translations(id) ON DELETE CASCADE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_favorite_user_translation UNIQUE (user_id, translation_id)
);

CREATE TABLE documents (
    id              VARCHAR(36) PRIMARY KEY,
    user_id         VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    filename        VARCHAR(255) NOT NULL,
    content_type    VARCHAR(100) NOT NULL,
    size_bytes      BIGINT NOT NULL,
    source_lang     VARCHAR(10) NOT NULL DEFAULT 'auto',
    target_lang     VARCHAR(10) NOT NULL,
    status          document_status NOT NULL DEFAULT 'processing',
    translated_text TEXT,
    error           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_documents_user ON documents (user_id);

CREATE TABLE plans (
    id                      VARCHAR(36) PRIMARY KEY,
    tier                    plan_tier NOT NULL UNIQUE,
    name                    VARCHAR(100) NOT NULL,
    price_monthly_cents     INTEGER NOT NULL DEFAULT 0,
    currency                VARCHAR(3) NOT NULL DEFAULT 'EUR',
    daily_translation_limit INTEGER,
    max_document_size_mb    INTEGER NOT NULL DEFAULT 5,
    premium_voices          BOOLEAN NOT NULL DEFAULT FALSE,
    ads_free                BOOLEAN NOT NULL DEFAULT FALSE,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE subscriptions (
    id                       VARCHAR(36) PRIMARY KEY,
    user_id                  VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id                  VARCHAR(36) NOT NULL REFERENCES plans(id),
    status                   subscription_status NOT NULL DEFAULT 'active',
    provider                 VARCHAR(50) NOT NULL DEFAULT 'stripe',
    provider_subscription_id VARCHAR(255),
    current_period_start     TIMESTAMPTZ NOT NULL DEFAULT now(),
    current_period_end       TIMESTAMPTZ,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_subscriptions_user ON subscriptions (user_id);

CREATE TABLE payments (
    id                         VARCHAR(36) PRIMARY KEY,
    user_id                    VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subscription_id            VARCHAR(36) REFERENCES subscriptions(id) ON DELETE SET NULL,
    amount                     NUMERIC(10,2) NOT NULL,
    currency                   VARCHAR(3) NOT NULL DEFAULT 'EUR',
    status                     payment_status NOT NULL DEFAULT 'pending',
    provider                   VARCHAR(50) NOT NULL DEFAULT 'stripe',
    provider_payment_id        VARCHAR(255),
    encrypted_payment_metadata TEXT,
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_payments_user ON payments (user_id);

CREATE TABLE usage_logs (
    id         BIGSERIAL PRIMARY KEY,
    user_id    VARCHAR(36) REFERENCES users(id) ON DELETE SET NULL,
    action     VARCHAR(100) NOT NULL,
    detail     TEXT,
    ip_address VARCHAR(45),
    user_agent VARCHAR(512),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_usage_logs_user ON usage_logs (user_id);
CREATE INDEX idx_usage_logs_action_created ON usage_logs (action, created_at DESC);

-- ---------------------------------------------------------------------
-- Seeds: planos e idiomas principais (lista completa carregada pela API)
-- ---------------------------------------------------------------------
INSERT INTO plans (id, tier, name, price_monthly_cents, daily_translation_limit, max_document_size_mb, premium_voices, ads_free) VALUES
    (gen_random_uuid()::text, 'free',     'Gratuito', 0,    100,  5,  FALSE, FALSE),
    (gen_random_uuid()::text, 'premium',  'Premium',  799,  NULL, 50, TRUE,  TRUE),
    (gen_random_uuid()::text, 'business', 'Business', 2499, NULL, 200, TRUE, TRUE);

INSERT INTO languages (code, name, native_name, supports_offline) VALUES
    ('af','Afrikaans','Afrikaans',false),('am','Amharic','አማርኛ',false),('ar','Arabic','العربية',true),
    ('az','Azerbaijani','Azərbaycan',false),('be','Belarusian','Беларуская',false),('bg','Bulgarian','Български',false),
    ('bn','Bengali','বাংলা',true),('bs','Bosnian','Bosanski',false),('ca','Catalan','Català',false),
    ('cs','Czech','Čeština',true),('cy','Welsh','Cymraeg',false),('da','Danish','Dansk',true),
    ('de','German','Deutsch',true),('el','Greek','Ελληνικά',true),('en','English','English',true),
    ('es','Spanish','Español',true),('et','Estonian','Eesti',false),('eu','Basque','Euskara',false),
    ('fa','Persian','فارسی',false),('fi','Finnish','Suomi',true),('fil','Filipino','Filipino',false),
    ('fr','French','Français',true),('ga','Irish','Gaeilge',false),('gl','Galician','Galego',false),
    ('gu','Gujarati','ગુજરાતી',false),('ha','Hausa','Hausa',false),('he','Hebrew','עברית',true),
    ('hi','Hindi','हिन्दी',true),('hr','Croatian','Hrvatski',false),('hu','Hungarian','Magyar',true),
    ('hy','Armenian','Հայերեն',false),('id','Indonesian','Bahasa Indonesia',true),('ig','Igbo','Igbo',false),
    ('is','Icelandic','Íslenska',false),('it','Italian','Italiano',true),('ja','Japanese','日本語',true),
    ('jv','Javanese','Basa Jawa',false),('ka','Georgian','ქართული',false),('kk','Kazakh','Қазақ',false),
    ('km','Khmer','ខ្មែរ',false),('kn','Kannada','ಕನ್ನಡ',false),('ko','Korean','한국어',true),
    ('ku','Kurdish','Kurdî',false),('ky','Kyrgyz','Кыргызча',false),('lo','Lao','ລາວ',false),
    ('lt','Lithuanian','Lietuvių',false),('lv','Latvian','Latviešu',false),('mg','Malagasy','Malagasy',false),
    ('mk','Macedonian','Македонски',false),('ml','Malayalam','മലയാളം',false),('mn','Mongolian','Монгол',false),
    ('mr','Marathi','मराठी',false),('ms','Malay','Bahasa Melayu',true),('mt','Maltese','Malti',false),
    ('my','Burmese','မြန်မာ',false),('ne','Nepali','नेपाली',false),('nl','Dutch','Nederlands',true),
    ('no','Norwegian','Norsk',true),('ny','Chichewa','Chichewa',false),('pa','Punjabi','ਪੰਜਾਬੀ',false),
    ('pl','Polish','Polski',true),('ps','Pashto','پښتو',false),('pt','Portuguese','Português',true),
    ('pt-BR','Portuguese (Brazil)','Português (Brasil)',true),('ro','Romanian','Română',true),
    ('ru','Russian','Русский',true),('rw','Kinyarwanda','Kinyarwanda',false),('sd','Sindhi','سنڌي',false),
    ('si','Sinhala','සිංහල',false),('sk','Slovak','Slovenčina',false),('sl','Slovenian','Slovenščina',false),
    ('sm','Samoan','Gagana Samoa',false),('sn','Shona','chiShona',false),('so','Somali','Soomaali',false),
    ('sq','Albanian','Shqip',false),('sr','Serbian','Српски',false),('st','Sesotho','Sesotho',false),
    ('su','Sundanese','Basa Sunda',false),('sv','Swedish','Svenska',true),('sw','Swahili','Kiswahili',true),
    ('ta','Tamil','தமிழ்',true),('te','Telugu','తెలుగు',false),('tg','Tajik','Тоҷикӣ',false),
    ('th','Thai','ไทย',true),('tk','Turkmen','Türkmen',false),('tr','Turkish','Türkçe',true),
    ('tt','Tatar','Татар',false),('ug','Uyghur','ئۇيغۇرچە',false),('uk','Ukrainian','Українська',true),
    ('ur','Urdu','اردو',true),('uz','Uzbek','Oʻzbek',false),('vi','Vietnamese','Tiếng Việt',true),
    ('xh','Xhosa','isiXhosa',false),('yi','Yiddish','ייִדיש',false),('yo','Yoruba','Yorùbá',false),
    ('zh','Chinese (Simplified)','简体中文',true),('zh-TW','Chinese (Traditional)','繁體中文',true),
    ('zu','Zulu','isiZulu',false),('lb','Luxembourgish','Lëtzebuergesch',false),('eo','Esperanto','Esperanto',false),
    ('ht','Haitian Creole','Kreyòl ayisyen',false),('haw','Hawaiian','ʻŌlelo Hawaiʻi',false),
    ('co','Corsican','Corsu',false),('fy','Frisian','Frysk',false),('gd','Scottish Gaelic','Gàidhlig',false),
    ('la','Latin','Latina',false),('mi','Maori','Te Reo Māori',false),('or','Odia','ଓଡ଼ିଆ',false);
