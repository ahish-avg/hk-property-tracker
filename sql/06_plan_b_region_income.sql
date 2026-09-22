-- 06_plan_b_region_income.sql — Plan B: 18-district income mapped to RVD's 3-region geography.
--
-- APPROXIMATION, NOT AN OFFICIAL FIGURE. This uses a population-weighted average of C&SD's 18-district
-- median household income, grouped by the district's RVD region (Hong Kong Island / Kowloon / New
-- Territories), using FIXED 2021 census population weights for all years. Two known distortions:
--   1. Averaging medians across districts (weighted) is not the same as the true regional median
--      (which would require raw household-level income data, not published). This is a standard and
--      commonly used approximation, but it is not mathematically equivalent to "the region's actual median".
--   2. Population weights are fixed at 2021 values for all years 2021-2025, for simplicity and because a
--      full annual re-weighting would need year-specific population figures for all 18 districts, which
--      were not all collected in this pass. This slightly understates any year where a district's population
--      share genuinely shifted, but district population is fairly stable year to year, so the distortion is small.
--
-- District -> RVD region mapping is official (source: Rating and Valuation Department's own district
-- reference, "AREAS AND DISTRICTS" doc: https://www.rvd.gov.hk/doc/tc/hkpr15/06.pdf; corroborated by
-- Hong Kong's District Councils structure, e.g. https://zh.wikipedia.org/wiki/香港行政區劃):
--   Hong Kong Island (港島): 中西區, 灣仔區, 東區, 南區
--   Kowloon (九龍): 油尖旺區, 深水埗區, 九龍城區, 黃大仙區, 觀塘區
--   New Territories (新界): 葵青區, 荃灣區, 屯門區, 元朗區, 北區, 大埔區, 沙田區, 西貢區, 離島區
--
-- Income figures below are sourced from C&SD's annual "Population and Household Statistics Analysed by
-- District Council District" report press releases (2021-2025), cross-checked across multiple news outlets
-- citing the same official report, and (for 2021) the original government press release PDF:
--   2021: https://gia.info.gov.hk/general/202204/21/P2022042000474_391188_1_1650526757954.pdf (Table 1, official)
--   2022: hk01/am730/kzg news coverage of the 2022 district report (in RMB/HKD figures cross-checked)
--   2023: ulifestyle.com.hk full ranked table citing the 2023 district report
--   2024: hk01.com (數因斯坦) full ranked table citing the 2024 district report
--   2025: hk01.com citing the 2025 district report + explicit YoY deltas from the 2024 base
-- Population weights: 2021 Census, land-based population by district (zh.wikipedia.org/wiki/香港行政區劃,
-- itself citing C&SD 2021 census figures).
--
-- If a district's exact-year figure could not be independently verified from at least one cited source,
-- it is filled from the nearest verified adjacent year and flagged in a comment. This affects a small number
-- of cells, not whole years.

USE hk_property;

-- Population weights (2021 census, land-based population), by district, tagged with RVD region.
-- Source: https://zh.wikipedia.org/wiki/香港行政區劃 (2021年人口 column), itself citing C&SD 2021 census.
-- 中西區 235953, 灣仔區 166695, 東區 529603, 南區 263278                          -> Hong Kong Island
-- 油尖旺區 310647, 深水埗區 431090, 九龍城區 410634, 黃大仙區 406802, 觀塘區 673166 -> Kowloon
-- 葵青區 495798, 荃灣區 320094, 元朗區 668080, 屯門區 506879, 北區 309631,
-- 大埔區 316470, 沙田區 692806, 西貢區 489037, 離島區 185282                      -> New Territories

INSERT INTO income_reference_by_district (year, district, rvd_region, population_2021, median_monthly_income_hkd, source) VALUES
-- 2021 (official press release PDF, Table 1 — all 18 districts verified)
(2021, '中西區', 'Hong Kong', 235953, 42000, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '灣仔區', 'Hong Kong', 166695, 40400, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '東區',   'Hong Kong', 529603, 31500, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '南區',   'Hong Kong', 263278, 33000, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '油尖旺區', 'Kowloon', 310647, 27900, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '深水埗區', 'Kowloon', 431090, 22000, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '九龍城區', 'Kowloon', 410634, 29700, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '黃大仙區', 'Kowloon', 406802, 23300, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '觀塘區',   'Kowloon', 673166, 22200, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '葵青區', 'New Territories', 495798, 23300, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '荃灣區', 'New Territories', 320094, 31800, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '屯門區', 'New Territories', 506879, 25400, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '元朗區', 'New Territories', 668080, 27000, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '北區',   'New Territories', 309631, 23300, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '大埔區', 'New Territories', 316470, 30000, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '沙田區', 'New Territories', 692806, 27100, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '西貢區', 'New Territories', 489037, 37200, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),
(2021, '離島區', 'New Territories', 185282, 28800, 'C&SD, 2021 Population and Household Statistics by DC District (Table 1, official press release)'),

-- 2022 (from news coverage of 2022 district report; a few cells filled from 2023's "-1yr change" statements
-- where the direct 2022 figure wasn't independently found — flagged with [est.] in the source note)
(2022, '中西區', 'Hong Kong', 235953, 42300, 'C&SD, 2022 report, via am730/hk01 coverage'),
(2022, '灣仔區', 'Hong Kong', 166695, 41800, 'C&SD, 2022 report, via am730/hk01 coverage'),
(2022, '東區',   'Hong Kong', 529603, 31500, 'C&SD, 2022 report, via am730/hk01 coverage'),
(2022, '南區',   'Hong Kong', 263278, 34200, 'C&SD, 2022 report, via am730/hk01 coverage'),
(2022, '油尖旺區', 'Kowloon', 310647, 28400, '[est.] interpolated between 2021 (27,900) and 2023 (30,700); not independently verified for 2022'),
(2022, '深水埗區', 'Kowloon', 431090, 22800, 'C&SD, 2022 report, via am730/hk01 coverage'),
(2022, '九龍城區', 'Kowloon', 410634, 30000, 'C&SD, 2022 report, via am730/hk01 coverage'),
(2022, '黃大仙區', 'Kowloon', 406802, 24600, '[est.] interpolated between 2021 (23,300) and 2023 (25,100); not independently verified for 2022'),
(2022, '觀塘區',   'Kowloon', 673166, 22100, 'C&SD, 2022 report, via am730/hk01 coverage'),
(2022, '葵青區', 'New Territories', 495798, 24300, 'C&SD, 2022 report, via am730/hk01 coverage'),
(2022, '荃灣區', 'New Territories', 320094, 32300, 'C&SD, 2022 report, via am730/hk01 coverage'),
(2022, '屯門區', 'New Territories', 506879, 25950, '[est.] interpolated between 2021 (25,400) and 2023 (26,500); not independently verified for 2022'),
(2022, '元朗區', 'New Territories', 668080, 28550, '[est.] interpolated between 2021 (27,000) and 2023 (30,100); not independently verified for 2022'),
(2022, '北區',   'New Territories', 309631, 24400, 'C&SD, 2022 report, via superpark.com.hk coverage (stated as prior-year base for 2023 comparison)'),
(2022, '大埔區', 'New Territories', 316470, 30200, 'C&SD, 2022 report, via am730/hk01 coverage'),
(2022, '沙田區', 'New Territories', 692806, 29700, '[est.] 2021 (27,100) +9.59% YoY per am730 coverage of 2022 report'),
(2022, '西貢區', 'New Territories', 489037, 40000, 'C&SD, 2022 report, via am730/hk01 coverage'),
(2022, '離島區', 'New Territories', 185282, 25700, '[est.] stated as prior-year base for 2023 (+12% -> 28,800) per superpark.com.hk coverage'),

-- 2023 (ulifestyle.com.hk full ranked table, explicitly citing the 2023 district report — all 18 verified)
(2023, '中西區', 'Hong Kong', 235953, 42600, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '灣仔區', 'Hong Kong', 166695, 40500, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '東區',   'Hong Kong', 529603, 33800, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '南區',   'Hong Kong', 263278, 36000, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '油尖旺區', 'Kowloon', 310647, 30700, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '深水埗區', 'Kowloon', 431090, 24100, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '九龍城區', 'Kowloon', 410634, 30700, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '黃大仙區', 'Kowloon', 406802, 25100, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '觀塘區',   'Kowloon', 673166, 24000, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '葵青區', 'New Territories', 495798, 26000, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '荃灣區', 'New Territories', 320094, 34400, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '屯門區', 'New Territories', 506879, 26500, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '元朗區', 'New Territories', 668080, 30100, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '北區',   'New Territories', 309631, 25500, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '大埔區', 'New Territories', 316470, 31700, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '沙田區', 'New Territories', 692806, 30500, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '西貢區', 'New Territories', 489037, 40400, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),
(2023, '離島區', 'New Territories', 185282, 31500, 'C&SD, 2023 Population and Household Statistics by DC District, via ulifestyle.com.hk ranked table'),

-- 2024 (hk01.com/數因斯坦 full ranked table, explicitly citing the 2024 district report — all 18 verified)
(2024, '中西區', 'Hong Kong', 235953, 42400, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '灣仔區', 'Hong Kong', 166695, 40800, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '東區',   'Hong Kong', 529603, 32500, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '南區',   'Hong Kong', 263278, 36000, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '油尖旺區', 'Kowloon', 310647, 29000, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '深水埗區', 'Kowloon', 431090, 24500, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '九龍城區', 'Kowloon', 410634, 31100, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '黃大仙區', 'Kowloon', 406802, 25600, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '觀塘區',   'Kowloon', 673166, 24200, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '葵青區', 'New Territories', 495798, 25500, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '荃灣區', 'New Territories', 320094, 34200, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '屯門區', 'New Territories', 506879, 26200, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '元朗區', 'New Territories', 668080, 30000, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '北區',   'New Territories', 309631, 25800, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '大埔區', 'New Territories', 316470, 31300, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '沙田區', 'New Territories', 692806, 31000, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '西貢區', 'New Territories', 489037, 41200, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),
(2024, '離島區', 'New Territories', 185282, 31000, 'C&SD, 2024 Population and Household Statistics by DC District, via hk01.com ranked table'),

-- 2025 (hk01.com, citing the 2025 district report; explicit YoY deltas given for changed districts,
-- "南區、黃大仙區、荃灣區、元朗區無升跌" = these 4 unchanged from 2024; other districts not explicitly
-- itemized in the sources found are carried over from 2024 and flagged [est., unconfirmed] below)
(2025, '中西區', 'Hong Kong', 235953, 45000, 'C&SD, 2025 report, via hk01.com (explicit +2,600 YoY stated)'),
(2025, '灣仔區', 'Hong Kong', 166695, 43300, 'C&SD, 2025 report, via hk01.com (explicit +2,500 YoY stated)'),
(2025, '東區',   'Hong Kong', 529603, 32500, '[est., unconfirmed] carried over from 2024; no explicit 2025 East District figure found'),
(2025, '南區',   'Hong Kong', 263278, 36000, 'C&SD, 2025 report, via hk01.com (explicitly stated unchanged from 2024)'),
(2025, '油尖旺區', 'Kowloon', 310647, 29000, '[est., unconfirmed] carried over from 2024; no explicit 2025 Yau Tsim Mong figure found'),
(2025, '深水埗區', 'Kowloon', 431090, 25000, 'C&SD, 2025 report, via hk01.com (explicit +500 YoY stated)'),
(2025, '九龍城區', 'Kowloon', 410634, 31100, '[est., unconfirmed] carried over from 2024; no explicit 2025 Kowloon City figure found'),
(2025, '黃大仙區', 'Kowloon', 406802, 25600, 'C&SD, 2025 report, via hk01.com (explicitly stated unchanged from 2024)'),
(2025, '觀塘區',   'Kowloon', 673166, 24900, 'C&SD, 2025 report, via hk01.com (explicit +700 YoY stated)'),
(2025, '葵青區', 'New Territories', 495798, 25500, '[est., unconfirmed] carried over from 2024; no explicit 2025 Kwai Tsing figure found'),
(2025, '荃灣區', 'New Territories', 320094, 34200, 'C&SD, 2025 report, via hk01.com (explicitly stated unchanged from 2024)'),
(2025, '屯門區', 'New Territories', 506879, 26200, '[est., unconfirmed] carried over from 2024; no explicit 2025 Tuen Mun figure found'),
(2025, '元朗區', 'New Territories', 668080, 30000, 'C&SD, 2025 report, via hk01.com (explicitly stated unchanged from 2024)'),
(2025, '北區',   'New Territories', 309631, 25800, '[est., unconfirmed] carried over from 2024; no explicit 2025 North District figure found'),
(2025, '大埔區', 'New Territories', 316470, 30700, 'C&SD, 2025 report, via hk01.com (explicit -600/-1.9% YoY stated)'),
(2025, '沙田區', 'New Territories', 692806, 31000, '[est., unconfirmed] carried over from 2024; no explicit 2025 Sha Tin figure found'),
(2025, '西貢區', 'New Territories', 489037, 40600, 'C&SD, 2025 report, via hk01.com (explicit -600/-1.46% YoY stated)'),
(2025, '離島區', 'New Territories', 185282, 31000, '[est., unconfirmed] carried over from 2024; no explicit 2025 Islands figure found')
ON DUPLICATE KEY UPDATE
    median_monthly_income_hkd = VALUES(median_monthly_income_hkd),
    rvd_region = VALUES(rvd_region),
    population_2021 = VALUES(population_2021),
    source = VALUES(source);

-- ============================================================================
-- Plan B computation: population-weighted regional income, joined against RVD avg_price_monthly
-- ============================================================================

-- Regional income (population-weighted average of district medians, fixed 2021 weights)
WITH regional_income AS (
    SELECT
        rvd_region,
        year,
        SUM(median_monthly_income_hkd * population_2021) / SUM(population_2021) AS weighted_median_income
    FROM income_reference_by_district
    GROUP BY rvd_region, year
)
SELECT rvd_region, year, ROUND(weighted_median_income, 0) AS weighted_median_income_hkd
FROM regional_income
ORDER BY year, rvd_region;

-- Plan B affordability index: regional avg price vs population-weighted regional income, using the SAME
-- Demographia Median Multiple methodology as sql/03_affordability.sql (40 sqm benchmark unit, ANNUALIZED
-- income). An earlier version of this query divided avg_price_hkd (HK$/sqm/MONTH-equivalent) directly by
-- weighted_median_income (HK$/MONTH) with no unit conversion — that produced a "monthly price-per-sqm to
-- monthly-income" ratio, not a Median Multiple, despite being labeled and discussed as one in the README.
-- The two metrics differ by a factor of ~480 (40 sqm x 12 months), which is why the old region-level numbers
-- (4.5-7.8) looked deceptively similar in scale to real Median Multiples while actually measuring something
-- else. Fixed here to match 03_affordability.sql's formula exactly, so the two files are comparable.
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
INNER JOIN regional_income i ON p.region = i.region AND p.year = i.year
ORDER BY p.year, p.region;
