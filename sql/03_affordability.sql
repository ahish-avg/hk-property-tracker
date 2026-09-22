-- 03_affordability.sql — Affordability index, TERRITORY-WIDE ONLY (Plan A, per 2026-09-20 decision).
--
-- Why territory-wide only: RVD's avg_price_monthly splits region into Hong Kong/Kowloon/New Territories,
-- but C&SD's income_reference is only compatible at territory-wide granularity (income_reference_by_district
-- uses the 18 District Council districts, a different geography that doesn't map cleanly onto RVD's 3 regions).
-- Computing a region-level affordability ratio would require a lossy 18-district -> 3-region income mapping.
-- That's deferred as a stretch goal (see README "Plan B"), not done here.
--
-- Window: 2021-2025, the only years where both price_index_monthly and income_reference overlap.

USE hk_property;

-- Affordability index by year (territory-wide), using the "All Classes" price index as the price series
-- and annual median household income. Index expressed as: avg monthly price_index level / median monthly income.
-- Note: price_index is a relative index (1999=100), not an absolute HK$ price, so this ratio is only meaningful
-- for YEAR-ON-YEAR TREND comparison, not as an absolute "X years of income to buy a home" figure.
-- For an absolute affordability read, use avg_price_monthly (HK$/sqm) against income instead — see query 2 below.

-- Query 1: index-based trend (relative, year-over-year comparable)
WITH annual_index AS (
    SELECT year, AVG(price_index) AS avg_annual_index
    FROM price_index_monthly
    WHERE class = 'ALL' AND year BETWEEN 2021 AND 2025
    GROUP BY year
)
SELECT
    a.year,
    a.avg_annual_index,
    i.median_monthly_income_hkd,
    ROUND(a.avg_annual_index / i.median_monthly_income_hkd * 1000, 4) AS index_to_income_ratio,
    ROUND(
        (a.avg_annual_index - LAG(a.avg_annual_index) OVER (ORDER BY a.year))
        / LAG(a.avg_annual_index) OVER (ORDER BY a.year) * 100
    , 2) AS index_yoy_pct_change,
    ROUND(
        (i.median_monthly_income_hkd - LAG(i.median_monthly_income_hkd) OVER (ORDER BY a.year))
        / LAG(i.median_monthly_income_hkd) OVER (ORDER BY a.year) * 100
    , 2) AS income_yoy_pct_change
FROM annual_index a
INNER JOIN income_reference i ON a.year = i.year
ORDER BY a.year;

-- Query 2: absolute affordability using the Demographia "Median Multiple" standard.
--
-- Source: Demographia International Housing Affordability Survey (annual editions 2017-2025), which defines
-- Median Multiple = median house price / gross annual median household income. This ratio is recommended
-- by the World Bank, UN, OECD, IMF, and used by the Harvard Joint Center for Housing Studies. Demographia's
-- own affordability bands (unchanged across editions through at least 2025):
--   Affordable            <= 3.0
--   Moderately Unaffordable  3.1 - 4.0
--   Seriously Unaffordable   4.1 - 5.0
--   Severely Unaffordable  >= 5.1
-- (Source: demographia.com/dhi-ratings.pdf; Demographia International Housing Affordability, 2025 Edition,
-- Table ES-1. Hong Kong has been Demographia's least-affordable major market on this measure every year it
-- has been surveyed, typically 14-23x — so results at or above "severely unaffordable" here are expected
-- and consistent with independent reporting, not a modeling artifact.)
--
-- Median Multiple needs a whole-DWELLING median price, not a per-sqm figure. avg_price_monthly is HK$/sqm
-- of saleable area, so it must be multiplied by a benchmark unit size to become comparable. This project
-- uses 40 sqm (~430 sqft) as an illustrative small-flat benchmark, chosen because it approximates a modest
-- 1-2 person unit common in HK's private housing stock — but this is a project assumption, not an RVD or
-- C&SD published benchmark unit size. Changing the assumed unit size scales every ratio in this query
-- proportionally; state the assumption whenever this number is shown.
WITH annual_avg_price AS (
    SELECT year, AVG(avg_price_hkd) AS avg_annual_price_per_sqm
    FROM avg_price_monthly
    WHERE year BETWEEN 2021 AND 2025
    GROUP BY year
)
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
FROM annual_avg_price p
INNER JOIN income_reference i ON p.year = i.year
ORDER BY p.year;
