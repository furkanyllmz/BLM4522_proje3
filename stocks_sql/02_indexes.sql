-- ============================================================
-- ADIM 2: İndeks Yönetimi
-- Komut: psql -U postgres -d stocks_db -f stocks_sql/02_indexes.sql
-- ============================================================

\connect stocks_db

-- ============================================================
-- 2.1 TEMEL İNDEKSLER
-- ============================================================

-- En sık kullanılan filtreler: symbol + date
CREATE INDEX IF NOT EXISTS idx_stock_symbol
    ON stock_prices (symbol);

CREATE INDEX IF NOT EXISTS idx_stock_date
    ON stock_prices (trade_date);

-- Bileşik indeks: belirli bir hisse senedinin tarih aralığı sorguları
-- WHERE symbol = 'AAPL' AND trade_date BETWEEN ... sorgusunu kapsar
CREATE INDEX IF NOT EXISTS idx_stock_symbol_date
    ON stock_prices (symbol, trade_date DESC);

-- ============================================================
-- 2.2 KAPSAYAN (COVERING) İNDEKSLER
-- ============================================================

-- Analistlerin en çok çalıştırdığı sorgu: OHLCV verisi
-- Index-only scan için close ve volume sütunlarını dahil et
CREATE INDEX IF NOT EXISTS idx_stock_symbol_date_covering
    ON stock_prices (symbol, trade_date DESC)
    INCLUDE (open_price, high_price, low_price, close_price, volume);

-- Hacim bazlı sorgular için (en çok işlem gören hisseler)
CREATE INDEX IF NOT EXISTS idx_stock_volume
    ON stock_prices (volume DESC);

-- Günlük değişim bazlı sorgular (en çok yükselen/düşen)
CREATE INDEX IF NOT EXISTS idx_stock_daily_change
    ON stock_prices (daily_change DESC);

-- ============================================================
-- 2.3 KISMI (PARTIAL) İNDEKSLER
-- ============================================================

-- Sadece pozitif günlük değişim (yükseliş günleri) için indeks
-- Tüm tablonun ~%50'si; negatif değişim sorgularını dışarıda bırakır
CREATE INDEX IF NOT EXISTS idx_stock_positive_days
    ON stock_prices (symbol, trade_date)
    WHERE daily_change > 0;

-- Yüksek hacimli işlem günleri (ortalama üstü hacim)
-- Hacim > 1 milyon olan satırlar için kısmi indeks
CREATE INDEX IF NOT EXISTS idx_high_volume_days
    ON stock_prices (symbol, trade_date, volume)
    WHERE volume > 1000000;

-- ============================================================
-- 2.4 FONKSİYONEL İNDEKSLER
-- ============================================================

-- Yıl bazlı gruplama sorguları için
CREATE INDEX IF NOT EXISTS idx_stock_year
    ON stock_prices (EXTRACT(YEAR FROM trade_date), symbol);

-- ============================================================
-- 2.5 İNDEKS DURUMU KONTROLÜ
-- ============================================================

SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE tablename = 'stock_prices'
ORDER BY pg_relation_size(indexrelid) DESC;

\echo 'Tum indeksler olusturuldu.'
