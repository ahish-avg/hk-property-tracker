-- 07_tableau_views.sql — MySQL views encapsulating the three verified analyses for Tableau consumption.
--
-- These views exist so Tableau only needs to drag a table in, with no GUI-side JOINs, window functions,
-- or unit-conversion logic re-implemented on the visualization side. Each view mirrors the FINAL, verified
-- query from its source SQL file exactly:
--   v_affordability_trend      <- 03_affordability.sql, Query 2 (territory-wide Median Multiple)
--   v_region_price             <- 05_region_comparison.sql, Query 1 (region price + YoY + rank)
--   v_region_median_multiple   <- 06_plan_b_region_income.sql, final corrected query (region-weighted
--                                  Median Multiple, with the 40sqm/x12 unit conversion — do not simplify)
--
-- Expected reference numbers (2021), per README "Key Findings", for post-creation validation:
--   v_affordability_trend:     22.22 (territory-wide)
--   v_region_median_multiple:  Kowloon 26.10, Hong Kong 21.34, New Territories 15.85

USE hk_property;

-- ============================================================================
-- v_affordability_trend — territory-wide Median Multiple, 2021-2025 (Plan A)
-- Mirrors 03_affordability.sql Query 2 exactly (40 sqm benchmark, annualized income).
-- ============================================================================
CREATE OR REPLACE VIEW v_affordability_trend AS
SELECT
    p.year,
    ROUND(p.avg_annual_price_per_sqm, 0) AS avg_price_hkd_per_sqm,
    ROUND(p.avg_annual_price_per_sqm * 40, 0) AS implied_price_40sqm_unit,
    i.median_monthly_income_hkd * 12 AS annual_median_income_hkd,
    ROUND((p.avg_annual_price_per_sqm * 40) / (i.median_monthly_income_hkd * 12), 2) AS median_multiple,
    CASE
        WHEN (p.avg_annual_price_per_sqm * 40) / (i.median_monthly_income_hkd * 12) >= 5.1 THEN 'severely_unaffordable'
        WHEN (p.avg_annual_price_per_sqm * 40) / (i.median_monthly_income_hkd * 12) >= 4.1 THEN 'seriously_unaffordable'
        WHEN (p.avg_annual_price_per_sqm * 40) / (i.median_monthly_income_hkd * 12) >= 3.1 THEN 'moderately_unaffordable'
        ELSE 'affordable'
    END AS status
FROM (
    SELECT year, AVG(avg_price_hkd) AS avg_annual_price_per_sqm
    FROM avg_price_monthly
    WHERE year BETWEEN 2021 AND 2025
    GROUP BY year
) p
INNER JOIN income_reference i ON p.year = i.year;

-- ============================================================================
-- v_region_price — region-level average price, YoY change, and rank (Plan A price view)
-- Mirrors 05_region_comparison.sql Query 1 exactly.
-- ============================================================================
CREATE OR REPLACE VIEW v_region_price AS
WITH region_yearly AS (
    SELECT
        region,
        year,
        AVG(avg_price_hkd) AS avg_price
    FROM avg_price_monthly
    WHERE year BETWEEN 2021 AND 2025
    GROUP BY region, year
),
region_with_change AS (
    SELECT
        region, year, avg_price,
        LAG(avg_price) OVER (PARTITION BY region ORDER BY year) AS prev_year_price
    FROM region_yearly
)
SELECT
    region, year,
    ROUND(avg_price, 0) AS avg_price_hkd,
    ROUND((avg_price - prev_year_price) / prev_year_price * 100, 2) AS yoy_pct_change,
    RANK() OVER (PARTITION BY year ORDER BY avg_price DESC) AS price_rank_desc
FROM region_with_change;

-- ============================================================================
-- v_region_median_multiple — region-level, population-weighted Median Multiple (Plan B)
-- Mirrors 06_plan_b_region_income.sql's FINAL CORRECTED query exactly, including the
-- 40sqm x 12mo unit conversion. Do NOT reintroduce the earlier draft that divided
-- avg_price_per_sqm directly by monthly income (that produced numbers ~480x too small).
-- ============================================================================
CREATE OR REPLACE VIEW v_region_median_multiple AS
WITH regional_income AS (
    SELECT
        rvd_region AS region,
        year,
        SUM(median_monthly_income_hkd * population_2021) / SUM(population_2021) AS weighted_median_income
    FROM income_reference_by_district
    GROUP BY rvd_region, year
),
regional_price AS (
    SELECT region, year, AVG(avg_price_hkd) AS avg_price_per_sqm
    FROM avg_price_monthly
    WHERE year BETWEEN 2021 AND 2025
    GROUP BY region, year
)
SELECT
    p.region,
    p.year,
    ROUND(p.avg_price_per_sqm, 0) AS avg_price_hkd_per_sqm,
    ROUND(p.avg_price_per_sqm * 40, 0) AS implied_price_40sqm_unit,
    ROUND(i.weighted_median_income * 12, 0) AS annual_weighted_median_income_hkd,
    ROUND((p.avg_price_per_sqm * 40) / (i.weighted_median_income * 12), 2) AS median_multiple,
    CASE
        WHEN (p.avg_price_per_sqm * 40) / (i.weighted_median_income * 12) >= 5.1 THEN 'severely_unaffordable'
        WHEN (p.avg_price_per_sqm * 40) / (i.weighted_median_income * 12) >= 4.1 THEN 'seriously_unaffordable'
        WHEN (p.avg_price_per_sqm * 40) / (i.weighted_median_income * 12) >= 3.1 THEN 'moderately_unaffordable'
        ELSE 'affordable'
    END AS status
FROM regional_price p
INNER JOIN regional_income i ON p.region = i.region AND p.year = i.year;
