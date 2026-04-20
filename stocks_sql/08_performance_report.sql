-- ============================================================
-- ADIM 8: Performans Özet Raporu ve Karşılaştırma
-- Komut: psql -U postgres -d stocks_db -f stocks_sql/08_performance_report.sql
-- ============================================================

\connect stocks_db

\echo '=========================================='
\echo ' STOCKS_DB PERFORMANS OZET RAPORU'
\echo '=========================================='

-- ============================================================
-- 8.1 VERİTABANI GENEL DURUMU
-- ============================================================

\echo '--- Veritabani Genel Bilgiler ---'

SELECT
    current_database()                  AS veritabani,
    COUNT(DISTINCT symbol)              AS toplam_hisse,
    COUNT(*)                            AS toplam_kayit,
    MIN(trade_date)                     AS baslangic_tarihi,
    MAX(trade_date)                     AS bitis_tarihi,
    pg_size_pretty(pg_database_size(current_database())) AS toplam_db_boyutu
FROM stock_prices;

-- ============================================================
-- 8.2 EN PERFORMANSLI İNDEKSLER
-- ============================================================

\echo '--- En cok kullanilan indeksler ---'

SELECT
    indexrelname                        AS indeks,
    idx_scan                            AS tarama_sayisi,
    pg_size_pretty(pg_relation_size(indexrelid)) AS boyut
FROM pg_stat_user_indexes
WHERE relname = 'stock_prices'
ORDER BY idx_scan DESC
LIMIT 5;

-- ============================================================
-- 8.3 SORGU PERFORMANS KARŞILAŞTIRMASı ÖZET TABLOSU
-- ============================================================

\echo '--- Sorgu performans karsilastirma ---'

-- Önce istatistikleri sıfırla (sadece test ortamında)
-- SELECT pg_stat_reset();

-- Test 1: İndekssiz arama simülasyonu (Sequential Scan)
SET enable_indexscan = OFF;
SET enable_bitmapscan = OFF;
SET enable_indexonlyscan = OFF;

DO $$
DECLARE
    v_start  TIMESTAMPTZ;
    v_end    TIMESTAMPTZ;
    v_ms     NUMERIC;
    v_rows   BIGINT;
BEGIN
    v_start := clock_timestamp();

    SELECT COUNT(*) INTO v_rows
    FROM stock_prices
    WHERE symbol = 'AAPL'
      AND trade_date BETWEEN '2015-01-01' AND '2015-12-31';

    v_end := clock_timestamp();
    v_ms  := EXTRACT(EPOCH FROM (v_end - v_start)) * 1000;

    INSERT INTO query_audit_log (username, query_text, duration_ms, rows_returned, notes)
    VALUES (
        current_user,
        'SELECT ... WHERE symbol=AAPL AND date BETWEEN 2015-01 AND 2015-12',
        v_ms,
        v_rows,
        'Sequential Scan (indeks devre disi)'
    );

    RAISE NOTICE 'Siral Tarama: % ms, % satir', ROUND(v_ms, 2), v_rows;
END $$;

-- Test 2: İndeksli arama
SET enable_indexscan = ON;
SET enable_bitmapscan = ON;
SET enable_indexonlyscan = ON;

DO $$
DECLARE
    v_start  TIMESTAMPTZ;
    v_end    TIMESTAMPTZ;
    v_ms     NUMERIC;
    v_rows   BIGINT;
BEGIN
    v_start := clock_timestamp();

    SELECT COUNT(*) INTO v_rows
    FROM stock_prices
    WHERE symbol = 'AAPL'
      AND trade_date BETWEEN '2015-01-01' AND '2015-12-31';

    v_end := clock_timestamp();
    v_ms  := EXTRACT(EPOCH FROM (v_end - v_start)) * 1000;

    INSERT INTO query_audit_log (username, query_text, duration_ms, rows_returned, notes)
    VALUES (
        current_user,
        'SELECT ... WHERE symbol=AAPL AND date BETWEEN 2015-01 AND 2015-12',
        v_ms,
        v_rows,
        'Index Scan (indeks aktif)'
    );

    RAISE NOTICE 'Indeks Tarama: % ms, % satir', ROUND(v_ms, 2), v_rows;
END $$;

-- ============================================================
-- 8.4 KARŞILAŞTIRMA RAPORU
-- ============================================================

\echo '--- Performans Karsilastirma Raporu ---'

SELECT
    notes                               AS test_tipi,
    ROUND(duration_ms, 3)               AS sure_ms,
    rows_returned                       AS satir_sayisi,
    logged_at                           AS test_zamani
FROM query_audit_log
ORDER BY logged_at DESC
LIMIT 10;

-- ============================================================
-- 8.5 ROL ERİŞİM DOĞRULAMA
-- ============================================================

\echo '--- Rol erisim haklari ozet ---'

SELECT
    grantee                             AS rol,
    table_name                          AS tablo,
    string_agg(privilege_type, ', ' ORDER BY privilege_type) AS yetkiler
FROM information_schema.role_table_grants
WHERE table_name IN ('stock_prices', 'query_audit_log')
  AND grantee NOT IN ('postgres', 'PUBLIC')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

-- ============================================================
-- 8.6 EN DEĞERLI ANALİTİK SORGULAR (İş Değeri)
-- ============================================================

\echo '--- Top 10 en yuksek hacimli hisse (tum zamanlar) ---'

SELECT
    symbol,
    SUM(volume)                         AS toplam_hacim,
    ROUND(AVG(close_price)::NUMERIC, 2) AS ort_kapanis,
    COUNT(*)                            AS islem_gunu
FROM stock_prices
GROUP BY symbol
ORDER BY SUM(volume) DESC
LIMIT 10;

\echo '--- Yillik ortalama getiri siralaması (2013-2018) ---'

WITH yillik AS (
    SELECT
        symbol,
        EXTRACT(YEAR FROM trade_date)::INT  AS yil,
        FIRST_VALUE(close_price) OVER (
            PARTITION BY symbol, EXTRACT(YEAR FROM trade_date)
            ORDER BY trade_date
        )                                   AS yil_basi_fiyat,
        LAST_VALUE(close_price) OVER (
            PARTITION BY symbol, EXTRACT(YEAR FROM trade_date)
            ORDER BY trade_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        )                                   AS yil_sonu_fiyat
    FROM stock_prices
)
SELECT
    symbol,
    ROUND(AVG((yil_sonu_fiyat - yil_basi_fiyat) /
              NULLIF(yil_basi_fiyat, 0) * 100)::NUMERIC, 2) AS ort_yillik_getiri_pct
FROM yillik
GROUP BY symbol
HAVING COUNT(DISTINCT yil) >= 4
ORDER BY ort_yillik_getiri_pct DESC
LIMIT 15;

\echo ''
\echo '=========================================='
\echo ' Performans raporu tamamlandi.'
\echo '=========================================='
