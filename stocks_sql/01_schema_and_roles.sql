-- ============================================================
-- ADIM 1: Şema, Tablo ve Rol Yapısı
-- Komut: psql -U postgres -d stocks_db -f stocks_sql/01_schema_and_roles.sql
-- ============================================================

\connect stocks_db

-- ============================================================
-- 1.1 ROL TANIMLARI (Veri Yöneticisi Rolleri)
-- ============================================================

-- Önceki rolleri temizle
DROP ROLE IF EXISTS stocks_admin;
DROP ROLE IF EXISTS stocks_analyst;
DROP ROLE IF EXISTS stocks_readonly;
DROP ROLE IF EXISTS stocks_etl;

-- Tam yetkili yönetici
CREATE ROLE stocks_admin LOGIN PASSWORD 'Admin@2024!' SUPERUSER CREATEDB CREATEROLE;

-- Analiz ve raporlama rolü (SELECT + aggregate sorgular)
CREATE ROLE stocks_analyst LOGIN PASSWORD 'Analyst@2024!';

-- Salt okunur erişim (raporlama araçları için)
CREATE ROLE stocks_readonly LOGIN PASSWORD 'Readonly@2024!';

-- ETL/veri yükleme rolü (INSERT yetkisi)
CREATE ROLE stocks_etl LOGIN PASSWORD 'Etl@2024!';

-- ============================================================
-- 1.2 ANA TABLO
-- ============================================================

CREATE TABLE IF NOT EXISTS stock_prices (
    id          BIGSERIAL PRIMARY KEY,
    trade_date  DATE          NOT NULL,
    open_price  NUMERIC(12,4) NOT NULL,
    high_price  NUMERIC(12,4) NOT NULL,
    low_price   NUMERIC(12,4) NOT NULL,
    close_price NUMERIC(12,4) NOT NULL,
    volume      BIGINT        NOT NULL,
    symbol      VARCHAR(10)   NOT NULL,
    -- Hesaplanan sütunlar (sorgularda sık kullanılır)
    daily_change   NUMERIC(12,4) GENERATED ALWAYS AS (close_price - open_price) STORED,
    daily_range    NUMERIC(12,4) GENERATED ALWAYS AS (high_price - low_price) STORED,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE stock_prices IS 'S&P 500 hisse senedi fiyat verileri (2013-2018)';

-- ============================================================
-- 1.3 PERFORMANS AUDIT TABLOSU
-- ============================================================

CREATE TABLE IF NOT EXISTS query_audit_log (
    id           BIGSERIAL PRIMARY KEY,
    logged_at    TIMESTAMPTZ DEFAULT NOW(),
    username     TEXT,
    query_text   TEXT,
    duration_ms  NUMERIC(10,3),
    rows_returned BIGINT,
    notes        TEXT
);

-- ============================================================
-- 1.4 YETKİ ATAMA
-- ============================================================

-- stocks_analyst: okuma + aggregate
GRANT CONNECT ON DATABASE stocks_db TO stocks_analyst;
GRANT USAGE ON SCHEMA public TO stocks_analyst;
GRANT SELECT ON stock_prices TO stocks_analyst;
GRANT SELECT ON query_audit_log TO stocks_analyst;

-- stocks_readonly: sadece okuma
GRANT CONNECT ON DATABASE stocks_db TO stocks_readonly;
GRANT USAGE ON SCHEMA public TO stocks_readonly;
GRANT SELECT ON stock_prices TO stocks_readonly;

-- stocks_etl: veri yükleme
GRANT CONNECT ON DATABASE stocks_db TO stocks_etl;
GRANT USAGE ON SCHEMA public TO stocks_etl;
GRANT INSERT, SELECT ON stock_prices TO stocks_etl;
GRANT USAGE ON SEQUENCE stock_prices_id_seq TO stocks_etl;

-- stocks_admin: her şey
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO stocks_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO stocks_admin;

\echo 'Roller, tablo ve yetkiler olusturuldu.'
