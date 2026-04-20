-- ============================================================
-- ADIM 4: Veritabanı İzleme - Dynamic Management Views (DMV)
-- PostgreSQL'in pg_stat_* görünümleri SQL Server DMV'lerine eşdeğerdir.
-- Komut: psql -U postgres -d stocks_db -f stocks_sql/04_monitoring_dmv.sql
-- ============================================================

\connect stocks_db

-- ============================================================
-- 4.1 TABLO İSTATİSTİKLERİ (pg_stat_user_tables)
-- SQL Server'daki sys.dm_db_index_usage_stats eşdeğeri
-- ============================================================

SELECT
    relname                             AS tablo_adi,
    n_live_tup                          AS canli_satir,
    n_dead_tup                          AS olü_satir,
    ROUND(n_dead_tup::NUMERIC /
        NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) AS bloat_yuzdesi,
    seq_scan                            AS siral_tarama_sayisi,
    idx_scan                            AS indeks_tarama_sayisi,
    ROUND(idx_scan::NUMERIC /
        NULLIF(seq_scan + idx_scan, 0) * 100, 2) AS indeks_kullanim_orani,
    last_vacuum,
    last_autovacuum,
    last_analyze
FROM pg_stat_user_tables
WHERE relname = 'stock_prices';

-- ============================================================
-- 4.2 İNDEKS KULLANIM İSTATİSTİKLERİ
-- SQL Server'daki sys.dm_db_index_usage_stats eşdeğeri
-- ============================================================

SELECT
    i.relname                           AS indeks_adi,
    t.relname                           AS tablo_adi,
    s.idx_scan                          AS kullanim_sayisi,
    s.idx_tup_read                      AS okunan_satir,
    s.idx_tup_fetch                     AS getirilen_satir,
    pg_size_pretty(pg_relation_size(s.indexrelid)) AS indeks_boyutu,
    CASE WHEN s.idx_scan = 0 THEN 'KULLANIMIYOR - Kaldir!' ELSE 'Aktif' END AS durum
FROM pg_stat_user_indexes s
JOIN pg_index ix ON s.indexrelid = ix.indexrelid
JOIN pg_class i  ON i.oid = s.indexrelid
JOIN pg_class t  ON t.oid = s.relid
WHERE t.relname = 'stock_prices'
ORDER BY s.idx_scan DESC;

-- ============================================================
-- 4.3 EN YAVAŞ SORGULAR (pg_stat_statements)
-- SQL Server'daki SQL Profiler / sys.dm_exec_query_stats eşdeğeri
-- pg_stat_statements uzantısı gereklidir
-- ============================================================

SELECT
    LEFT(query, 100)                    AS sorgu_ozeti,
    calls                               AS cagri_sayisi,
    ROUND(total_exec_time::NUMERIC, 2)  AS toplam_sure_ms,
    ROUND(mean_exec_time::NUMERIC, 2)   AS ortalama_sure_ms,
    ROUND(min_exec_time::NUMERIC, 2)    AS min_sure_ms,
    ROUND(max_exec_time::NUMERIC, 2)    AS max_sure_ms,
    rows                                AS toplam_satir
FROM pg_stat_statements
WHERE query ILIKE '%stock_prices%'
ORDER BY mean_exec_time DESC
LIMIT 20;

-- ============================================================
-- 4.4 AKTIF BAĞLANTILAR VE ÇALIŞAN SORGULAR
-- SQL Server'daki sys.dm_exec_requests eşdeğeri
-- ============================================================

SELECT
    pid,
    usename                             AS kullanici,
    application_name                    AS uygulama,
    state                               AS durum,
    ROUND(EXTRACT(EPOCH FROM (NOW() - query_start))::NUMERIC, 2) AS sure_saniye,
    LEFT(query, 120)                    AS sorgu
FROM pg_stat_activity
WHERE state != 'idle'
  AND query NOT ILIKE '%pg_stat_activity%'
ORDER BY query_start;

-- ============================================================
-- 4.5 TABLO BOYUTU VE BLOAT ANALİZİ
-- ============================================================

SELECT
    pg_size_pretty(pg_table_size('stock_prices'))           AS tablo_boyutu,
    pg_size_pretty(pg_indexes_size('stock_prices'))         AS indeks_boyutu,
    pg_size_pretty(pg_total_relation_size('stock_prices'))  AS toplam_boyut,
    ROUND(pg_indexes_size('stock_prices')::NUMERIC /
          pg_total_relation_size('stock_prices') * 100, 1) AS indeks_orani_pct;

-- ============================================================
-- 4.6 ÖNBELLEK İSABET ORANI (Cache Hit Ratio)
-- Bu oran %95+ olmalıdır; düşükse shared_buffers artırılmalı
-- ============================================================

SELECT
    sum(heap_blks_read)                         AS disk_okuma,
    sum(heap_blks_hit)                          AS onbellek_isabeti,
    ROUND(sum(heap_blks_hit)::NUMERIC /
        NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100, 2) AS onbellek_isabet_orani
FROM pg_statio_user_tables
WHERE relname = 'stock_prices';

\echo 'DMV izleme sorgulari calistirildi.'
