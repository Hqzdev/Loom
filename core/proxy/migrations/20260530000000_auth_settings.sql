CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    password_hash TEXT,
    google_id TEXT UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    theme TEXT NOT NULL DEFAULT 'dark',
    proxy_port INTEGER NOT NULL DEFAULT 8080,
    local_cache_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    api_key_openai TEXT,
    api_key_anthropic TEXT,
    CONSTRAINT user_settings_theme_check CHECK (theme IN ('system', 'light', 'dark')),
    CONSTRAINT user_settings_proxy_port_check CHECK (proxy_port BETWEEN 1 AND 65535)
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users (google_id);
