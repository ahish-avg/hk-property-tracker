-- 05_region_comparison.sql — Region-level average price trend & ranking (Hong Kong/Kowloon/New Territories),
-- 2021-2025. This REPLACES the original v2 memo's "does New Territories' transaction volume share rise"
-- hypothesis, which cannot be tested: RVD's sales_volume_monthly has no region breakdown (verified 2026-09-20,
-- see README). This uses avg_price_monthly instead, which DOES have region granularity.
--
-- Testable question: which region's average price fell/rose the most 2021-2025, and how does each region's
-- ranking evolve year over year?

USE hk_property;

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
FROM region_with_change
ORDER BY year, price_rank_desc;

-- Cumulative change 2021 -> 2025 per region, to directly answer "which region moved the most"
WITH region_yearly AS (
    SELECT region, year, AVG(avg_price_hkd) AS avg_price
    FROM avg_price_monthly
    WHERE year IN (2021, 2025)
    GROUP BY region, year
)
SELECT
    region,
    MAX(CASE WHEN year = 2021 THEN avg_price END) AS price_2021,
    MAX(CASE WHEN year = 2025 THEN avg_price END) AS price_2025,
    ROUND(
        (MAX(CASE WHEN year = 2025 THEN avg_price END) - MAX(CASE WHEN year = 2021 THEN avg_price END))
        / MAX(CASE WHEN year = 2021 THEN avg_price END) * 100
    , 2) AS cumulative_pct_change_2021_2025
FROM region_yearly
GROUP BY region
ORDER BY cumulative_pct_change_2021_2025 DESC;
