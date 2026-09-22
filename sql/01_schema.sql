-- HK Property Affordability Tracker — schema (v2, aligned with real RVD + C&SD data)
--
-- Verified data realities (2026-09-20):
--   * price_index_monthly  <- RVD 1.4M.csv : territory-wide ONLY, by Class A-E. No region breakdown.
--   * avg_price_monthly    <- RVD 1.2M.csv : by Class A-E x Region (Hong Kong/Kowloon/New Territories). 1999-present.
--   * sales_volume_monthly <- RVD 7.3.csv  : territory-wide ONLY (primary/secondary sale counts). No region breakdown.
--   * income_reference     <- C&SD annual district report (2021-2025 only, released ~1yr lag).
--                              Districts are the 18 Council Districts, NOT RVD's Hong Kong/Kowloon/NT split.
--                              Territory-wide median is also published and IS compatible with RVD region data
--                              only at territory-wide granularity.
--
-- Consequence: affordability index computed against income can only be done validly at TERRITORY-WIDE level.
-- District-level (18-district) income cannot be joined to RVD's 3-region (HK/Kowloon/NT) breakdown without a
-- lossy district->region mapping. We store both granularities and make the mismatch explicit rather than
-- silently joining incompatible geographies.

CREATE DATABASE IF NOT EXISTS hk_property CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE hk_property;

-- Territory-wide price index by class, monthly (RVD 1.4M.csv)
CREATE TABLE IF NOT EXISTS price_index_monthly (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    year            SMALLINT NOT NULL,
    month           TINYINT NOT NULL,
    class           ENUM('A','B','C','D','E','ABC','DE','ALL') NOT NULL,
    price_index     DECIMAL(10,2) NOT NULL,
    remark          VARCHAR(5) NULL,     -- 'P' = provisional
    source_file     VARCHAR(50) NOT NULL DEFAULT '1.4M.csv',
    loaded_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_index (year, month, class)
) ENGINE=InnoDB;

-- Average price by class and RVD region (Hong Kong / Kowloon / New Territories), monthly (RVD 1.2M.csv)
CREATE TABLE IF NOT EXISTS avg_price_monthly (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    year            SMALLINT NOT NULL,
    month           TINYINT NOT NULL,
    class           ENUM('A','B','C','D','E') NOT NULL,
    region          ENUM('Hong Kong','Kowloon','New Territories') NOT NULL,
    avg_price_hkd   DECIMAL(15,2) NOT NULL,   -- HK$ per square metre saleable area, per RVD definition
    remark          VARCHAR(5) NULL,
    source_file     VARCHAR(50) NOT NULL DEFAULT '1.2M.csv',
    loaded_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_avgprice (year, month, class, region)
) ENGINE=InnoDB;

-- Territory-wide sale & purchase agreement counts, monthly (RVD 7.3.csv). No region breakdown exists.
CREATE TABLE IF NOT EXISTS sales_volume_monthly (
    id                          BIGINT AUTO_INCREMENT PRIMARY KEY,
    year                        SMALLINT NOT NULL,
    month                       TINYINT NOT NULL,
    primary_sales_count         INT NOT NULL,
    primary_sales_consideration DECIMAL(18,2) NOT NULL,   -- HK$ million, per RVD unit
    secondary_sales_count       INT NOT NULL,
    secondary_sales_consideration DECIMAL(18,2) NOT NULL,
    source_file                 VARCHAR(50) NOT NULL DEFAULT '7.3.csv',
    loaded_at                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_volume (year, month)
) ENGINE=InnoDB;

-- Official median household income, TERRITORY-WIDE, annual (C&SD General Household Survey).
-- Compatible with RVD data at territory-wide granularity only. Data available 2021-2025 (released with ~1yr lag).
CREATE TABLE IF NOT EXISTS income_reference (
    id                          BIGINT AUTO_INCREMENT PRIMARY KEY,
    year                        SMALLINT NOT NULL,
    median_monthly_income_hkd  DECIMAL(10,2) NOT NULL,
    scope                       VARCHAR(100) NOT NULL DEFAULT 'All households, excl. foreign domestic helpers',
    source                      VARCHAR(255) NOT NULL DEFAULT 'C&SD, Population and Household Statistics by District Council District',
    loaded_at                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_income (year)
) ENGINE=InnoDB;

-- Official median household income by 18 District Council districts, annual (C&SD).
-- Used for Plan B: population-weighted rollup into RVD's Hong Kong/Kowloon/New Territories regions.
-- rvd_region and population_2021 support that rollup; see sql/06_plan_b_region_income.sql.
CREATE TABLE IF NOT EXISTS income_reference_by_district (
    id                          BIGINT AUTO_INCREMENT PRIMARY KEY,
    year                        SMALLINT NOT NULL,
    district                    VARCHAR(20) NOT NULL,   -- e.g. '中西區', '灣仔區', '觀塘區' ...
    rvd_region                  ENUM('Hong Kong','Kowloon','New Territories') NOT NULL,
    population_2021             INT NOT NULL,   -- 2021 census land-based population, used as a fixed weighting base
    median_monthly_income_hkd  DECIMAL(10,2) NOT NULL,
    source                      VARCHAR(255) NOT NULL DEFAULT 'C&SD, Population and Household Statistics by District Council District',
    loaded_at                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_income_district (year, district)
) ENGINE=InnoDB;

-- Seed: territory-wide median household income, 2021-2025 (source: C&SD annual district reports, as reported)
INSERT INTO income_reference (year, median_monthly_income_hkd, scope, source) VALUES
    (2021, 27500.00, 'All households, excl. foreign domestic helpers', 'C&SD, 2021 Population and Household Statistics by District Council District'),
    (2022, 28300.00, 'All households, excl. foreign domestic helpers', 'C&SD, 2022 Population and Household Statistics by District Council District'),
    (2023, 30000.00, 'All households, excl. foreign domestic helpers', 'C&SD, 2023 Population and Household Statistics by District Council District'),
    (2024, 30000.00, 'All households, excl. foreign domestic helpers', 'C&SD, 2024 Population and Household Statistics by District Council District'),
    (2025, 30000.00, 'All households, excl. foreign domestic helpers', 'C&SD, 2025 Population and Household Statistics by District Council District')
ON DUPLICATE KEY UPDATE median_monthly_income_hkd = VALUES(median_monthly_income_hkd);
