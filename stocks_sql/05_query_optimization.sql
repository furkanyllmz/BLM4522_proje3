-- ============================================================
-- ADIM 5: Sorgu İyileştirme - EXPLAIN ANALYZE Analizi
-- Komut: psql -U postgres -d stocks_db -f stocks_sql/05_query_optimization.sql
-- ============================================================

\connect stocks_db

-- ============================================================
-- 5.1 KÖTÜ SORGU - Sequential Scan (Optimizasyon Öncesi)
-- ============================================================

\echo '--- KOTU SORGU: Siral tarama (oncesi) ---'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT symbol, trade_date, close_price
FROM stock_prices
WHERE symbol = 'AAPL'
  AND trade_date BETWEEN '2015-01-01' AND '2016-12-31'
ORDER BY trade_date;

-- ============================================================
-- 5.2 OPTİMİZE SORGU - Index Scan (İndeks Sonrası)
-- (02_indexes.sql çalıştırıldıktan sonra aynı sorgu indeksi kullanır)
-- ============================================================

\echo '--- OPTIMIZE SORGU: Indeks taramasi (sonrasi) ---'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT symbol, trade_date, open_price, high_price, low_price, close_price, volume
FROM stock_prices
WHERE symbol = 'AAPL'
  AND trade_date BETWEEN '2015-01-01' AND '2016-12-31'
ORDER BY trade_date;

-- ============================================================
-- 5.3 UZUN SÜREN SORGU ÖRNEĞİ - N+1 tarzı kötü sorgu
-- Her hisse için ayrı ayrı MAX çekilmesi yerine pencere fonksiyonu
-- ============================================================

\echo '--- KOTU YAKLASIM: Correlated subquery ---'

EXPLAIN (ANALYZE, BUFFERS)
SELECT sp.symbol,
       sp.trade_date,
       sp.close_price,
       (SELECT MAX(close_price)
        FROM stock_prices sp2
        WHERE sp2.symbol = sp.symbol) AS tum_zamanin_zirve_fiyati
FROM stock_prices sp
WHERE sp.trade_date = '2017-01-03'
LIMIT 10;

-- ============================================================
-- 5.4 OPTİMİZE YAKLAŞIM - Pencere Fonksiyonu (Window Function)
-- ============================================================

\echo '--- OPTIMIZE YAKLASIM: Window function ---'

EXPLAIN (ANALYZE, BUFFERS)
SELECT DISTINCT
    symbol,
    trade_date,
    close_price,
    MAX(close_price) OVER (PARTITION BY symbol) AS tum_zamanin_zirve_fiyati
FROM stock_prices
WHERE trade_date = '2017-01-03';

-- ============================================================
-- 5.5 YAVAŞ AGGREGATE SORGU - Optimizasyon Karşılaştırması
-- ============================================================

\echo '--- Yillik ozet istatistikler (aggregate ornek) ---'

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    symbol,
    EXTRACT(YEAR FROM trade_date)       AS yil,
    COUNT(*)                            AS islem_gunu,
    ROUND(AVG(close_price)::NUMERIC, 2) AS ort_kapanis,
    MIN(low_price)                      AS yillik_dip,
    MAX(high_price)                     AS yillik_zirve,
    SUM(volume)                         AS toplam_hacim
FROM stock_prices
WHERE symbol IN ('AAPL', 'GOOGL', 'MSFT', 'AMZN', 'FB')
GROUP BY symbol, EXTRACT(YEAR FROM trade_date)
ORDER BY symbol, yil;

-- ============================================================
-- 5.6 GÜNLÜK EN ÇOK ARTAN/DÜŞEN HİSSELER
-- Pencere fonksiyonu ile sıralama
-- ============================================================

\echo '--- Her gun en cok artan 5 hisse ---'

WITH ranked AS (
    SELECT
        trade_date,
        symbol,
        daily_change,
        ROUND((daily_change / NULLIF(open_price, 0)) * 100, 2) AS degisim_yuzdesi,
        RANK() OVER (PARTITION BY trade_date ORDER BY daily_change DESC) AS siralama
    FROM stock_prices
    WHERE trade_date >= '2017-01-01'
      AND volume > 500000
)
SELECT trade_date, symbol, daily_change, degisim_yuzdesi, siralama
FROM ranked
WHERE siralama <= 5
ORDER BY trade_date DESC, siralama
LIMIT 50;

-- ============================================================
-- 5.7 HAREKETLİ ORTALAMA (Moving Average) - Analitik Sorgu
-- 20 günlük hareketli ortalama hesaplama
-- ============================================================

\echo '--- AAPL 20 gunluk hareketli ortalama ---'

SELECT
    trade_date,
    close_price,
    ROUND(AVG(close_price) OVER (
        PARTITION BY symbol
        ORDER BY trade_date
        ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
    )::NUMERIC, 4) AS hareketli_ort_20g,
    ROUND(AVG(close_price) OVER (
        PARTITION BY symbol
        ORDER BY trade_date
        ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
    )::NUMERIC, 4) AS hareketli_ort_50g
FROM stock_prices
WHERE symbol = 'AAPL'
ORDER BY trade_date
LIMIT 100;

\echo 'Sorgu optimizasyonu analizi tamamlandi.'
