-- ============================================================
-- FAZ 1 - ADIM 1: Veritabanı Kurulumu ve Tablo Mimarisi
-- Proje: Otel Rezervasyon Güvenlik Mimarisi
-- Veri Seti: Hotel Booking Demand (Kaggle)
-- ============================================================

-- pgcrypto uzantısını etkinleştir (şifreleme için)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- ANA TABLO: ham_rezervasyonlar (CSV'den doğrudan import)
-- ============================================================
DROP TABLE IF EXISTS ham_rezervasyonlar CASCADE;

CREATE TABLE ham_rezervasyonlar (
    id                              SERIAL PRIMARY KEY,
    hotel                           VARCHAR(50),
    is_canceled                     INTEGER,
    lead_time                       INTEGER,
    arrival_date_year               INTEGER,
    arrival_date_month              VARCHAR(20),
    arrival_date_week_number        INTEGER,
    arrival_date_day_of_month       INTEGER,
    stays_in_weekend_nights         INTEGER,
    stays_in_week_nights            INTEGER,
    adults                          INTEGER,
    children                        NUMERIC,
    babies                          INTEGER,
    meal                            VARCHAR(10),
    country                         VARCHAR(10),
    market_segment                  VARCHAR(30),
    distribution_channel            VARCHAR(30),
    is_repeated_guest               INTEGER,
    previous_cancellations          INTEGER,
    previous_bookings_not_canceled  INTEGER,
    reserved_room_type              VARCHAR(5),
    assigned_room_type              VARCHAR(5),
    booking_changes                 INTEGER,
    deposit_type                    VARCHAR(30),
    agent                           VARCHAR(20),
    company                         VARCHAR(20),
    days_in_waiting_list            INTEGER,
    customer_type                   VARCHAR(30),
    adr                             NUMERIC(10,2),
    required_car_parking_spaces     INTEGER,
    total_of_special_requests       INTEGER,
    reservation_status              VARCHAR(20),
    reservation_status_date         DATE
);

-- ============================================================
-- NORMALİZASYON: musteriler tablosu
-- ============================================================
DROP TABLE IF EXISTS musteriler CASCADE;

CREATE TABLE musteriler (
    musteri_id      SERIAL PRIMARY KEY,
    ulke            VARCHAR(10),
    musteri_tipi    VARCHAR(30),
    tekrar_misafir  INTEGER,
    -- Güvenlik: kredi kartı pgcrypto ile şifrelenmiş olarak saklanır
    kredi_karti     TEXT  -- pgcrypto::crypt() ile hashlenmiş değer
);

-- ============================================================
-- NORMALİZASYON: rezervasyonlar tablosu (ana iş tablosu)
-- ============================================================
DROP TABLE IF EXISTS rezervasyonlar CASCADE;

CREATE TABLE rezervasyonlar (
    rezervasyon_id              SERIAL PRIMARY KEY,
    musteri_id                  INTEGER REFERENCES musteriler(musteri_id),
    hotel                       VARCHAR(50),          -- 'City Hotel' veya 'Resort Hotel'
    is_canceled                 INTEGER,
    lead_time                   INTEGER,
    arrival_date_year           INTEGER,
    arrival_date_month          VARCHAR(20),
    arrival_date_week_number    INTEGER,
    arrival_date_day_of_month   INTEGER,
    stays_in_weekend_nights     INTEGER,
    stays_in_week_nights        INTEGER,
    adults                      INTEGER,
    children                    NUMERIC,
    babies                      INTEGER,
    meal                        VARCHAR(10),
    market_segment              VARCHAR(30),
    distribution_channel        VARCHAR(30),
    reserved_room_type          VARCHAR(5),
    assigned_room_type          VARCHAR(5),
    booking_changes             INTEGER,
    deposit_type                VARCHAR(30),
    agent                       VARCHAR(20),
    company                     VARCHAR(20),
    days_in_waiting_list        INTEGER,
    adr                         NUMERIC(10,2),        -- Average Daily Rate (güvenlik hedefi)
    required_car_parking_spaces INTEGER,
    total_of_special_requests   INTEGER,
    reservation_status          VARCHAR(20),
    reservation_status_date     DATE
);

-- ============================================================
-- VERİ AKTARIMI: ham tablodan normalize tablolara taşı
-- ============================================================

-- 1. Önce müşterileri oluştur (her ham satır için benzersiz müşteri)
INSERT INTO musteriler (ulke, musteri_tipi, tekrar_misafir, kredi_karti)
SELECT
    country,
    customer_type,
    is_repeated_guest,
    -- pgcrypto ile sahte kredi kartı numarası şifreleniyor
    -- crypt() fonksiyonu: bf = Blowfish algoritması, 10 tur
    crypt(
        '4' || LPAD((FLOOR(RANDOM() * 900000000000000) + 100000000000000)::TEXT, 15, '0'),
        gen_salt('bf', 10)
    )
FROM ham_rezervasyonlar;

-- 2. Rezervasyonları müşterilerle ilişkilendirerek aktar
INSERT INTO rezervasyonlar (
    musteri_id, hotel, is_canceled, lead_time,
    arrival_date_year, arrival_date_month, arrival_date_week_number, arrival_date_day_of_month,
    stays_in_weekend_nights, stays_in_week_nights,
    adults, children, babies, meal,
    market_segment, distribution_channel,
    reserved_room_type, assigned_room_type,
    booking_changes, deposit_type, agent, company,
    days_in_waiting_list, adr,
    required_car_parking_spaces, total_of_special_requests,
    reservation_status, reservation_status_date
)
SELECT
    m.musteri_id,
    h.hotel, h.is_canceled, h.lead_time,
    h.arrival_date_year, h.arrival_date_month, h.arrival_date_week_number, h.arrival_date_day_of_month,
    h.stays_in_weekend_nights, h.stays_in_week_nights,
    h.adults, h.children, h.babies, h.meal,
    h.market_segment, h.distribution_channel,
    h.reserved_room_type, h.assigned_room_type,
    h.booking_changes, h.deposit_type, h.agent, h.company,
    h.days_in_waiting_list, h.adr,
    h.required_car_parking_spaces, h.total_of_special_requests,
    h.reservation_status, h.reservation_status_date
FROM ham_rezervasyonlar h
JOIN musteriler m ON m.musteri_id = h.id;

-- Doğrulama sorguları
SELECT hotel, COUNT(*) as rezervasyon_sayisi FROM rezervasyonlar GROUP BY hotel;
SELECT COUNT(*) as toplam_musteri FROM musteriler;
SELECT musteri_id, LEFT(kredi_karti, 20) || '...' as sifreli_kart FROM musteriler LIMIT 5;
