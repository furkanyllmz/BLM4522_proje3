-- ============================================================
-- ADIM 0: Veritabanını Oluştur (psql ile süper kullanıcı olarak çalıştır)
-- Komut: psql -U postgres -f 00_create_database.sql
-- ============================================================

-- Varsa düşür ve yeniden oluştur
DROP DATABASE IF EXISTS hotel_db;
CREATE DATABASE hotel_db
    WITH
    OWNER      = postgres
    ENCODING   = 'UTF8'
    LC_COLLATE = 'tr_TR.UTF-8'
    LC_CTYPE   = 'tr_TR.UTF-8'
    TEMPLATE   = template0;

\connect hotel_db

-- pgcrypto uzantısını etkinleştir
CREATE EXTENSION IF NOT EXISTS pgcrypto;

\echo 'hotel_db veritabani ve pgcrypto uzantisi hazir.'
